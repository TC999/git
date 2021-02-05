/*
 * git decrypt builtin command
 *
 * Cleanup unreachable files and optimize the repository.
 *
 * Copyright (c) 2007 James Bowes
 *
 * Based on git-gc.sh, which is
 *
 * Copyright (c) 2006 Shawn O. Pearce
 */

#include "builtin.h"
#include "repository.h"
#include "config.h"
#include "tempfile.h"
#include "lockfile.h"
#include "parse-options.h"
#include "run-command.h"
#include "sigchain.h"
#include "commit.h"
#include "commit-graph.h"
#include "packfile.h"
#include "object-store.h"
#include "pack.h"
#include "pack-objects.h"
#include "blob.h"
#include "tree.h"
#include "promisor-remote.h"

#define FAILED_RUN "failed to run %s"

static const char * const builtin_decrypt_usage[] = {
	N_("git decrypt [<options>]"),
	NULL
};

static int aggressive_depth = 50;
static int aggressive_window = 250;
static unsigned long max_delta_cache_size = DEFAULT_DELTA_CACHE_SIZE;

static struct strvec repack = STRVEC_INIT;

static struct tempfile *pidfile;
static struct lock_file log_lock;

static struct string_list pack_garbage = STRING_LIST_INIT_DUP;

static void clean_pack_garbage(void)
{
	int i;
	for (i = 0; i < pack_garbage.nr; i++)
		unlink_or_warn(pack_garbage.items[i].string);
	string_list_clear(&pack_garbage, 0);
}

static void report_pack_garbage(unsigned seen_bits, const char *path)
{
	if (seen_bits == PACKDIR_FILE_IDX)
		string_list_append(&pack_garbage, path);
}

static void process_log_file(void)
{
	struct stat st;
	if (fstat(get_lock_file_fd(&log_lock), &st)) {
		/*
		 * Perhaps there was an i/o error or another
		 * unlikely situation.  Try to make a note of
		 * this in gc.log along with any existing
		 * messages.
		 */
		int saved_errno = errno;
		fprintf(stderr, _("Failed to fstat %s: %s"),
			get_tempfile_path(log_lock.tempfile),
			strerror(saved_errno));
		fflush(stderr);
		commit_lock_file(&log_lock);
		errno = saved_errno;
	} else if (st.st_size) {
		/* There was some error recorded in the lock file */
		commit_lock_file(&log_lock);
	} else {
		/* No error, clean up any old gc.log */
		unlink(git_path("gc.log"));
		rollback_lock_file(&log_lock);
	}
}

static void process_log_file_at_exit(void)
{
	fflush(stderr);
	process_log_file();
}

static void process_log_file_on_signal(int signo)
{
	process_log_file();
	sigchain_pop(signo);
	raise(signo);
}

static void decrypt_config(void)
{
	git_config_get_int("gc.aggressivewindow", &aggressive_window);
	git_config_get_int("gc.aggressivedepth", &aggressive_depth);

	git_config_get_ulong("pack.deltacachesize", &max_delta_cache_size);

	git_config(git_default_config, NULL);
}

/* return NULL on success, else hostname running the gc */
static const char *lock_repo_for_gc(int force, pid_t* ret_pid)
{
	struct lock_file lock = LOCK_INIT;
	char my_host[HOST_NAME_MAX + 1];
	struct strbuf sb = STRBUF_INIT;
	struct stat st;
	uintmax_t pid;
	FILE *fp;
	int fd;
	char *pidfile_path;

	if (is_tempfile_active(pidfile))
		/* already locked */
		return NULL;

	if (xgethostname(my_host, sizeof(my_host)))
		xsnprintf(my_host, sizeof(my_host), "unknown");

	pidfile_path = git_pathdup("gc.pid");
	fd = hold_lock_file_for_update(&lock, pidfile_path,
				       LOCK_DIE_ON_ERROR);
	if (!force) {
		static char locking_host[HOST_NAME_MAX + 1];
		static char *scan_fmt;
		int should_exit;

		if (!scan_fmt)
			scan_fmt = xstrfmt("%s %%%ds", "%"SCNuMAX, HOST_NAME_MAX);
		fp = fopen(pidfile_path, "r");
		memset(locking_host, 0, sizeof(locking_host));
		should_exit =
			fp != NULL &&
			!fstat(fileno(fp), &st) &&
			/*
			 * 12 hour limit is very generous as gc should
			 * never take that long. On the other hand we
			 * don't really need a strict limit here,
			 * running gc --auto one day late is not a big
			 * problem. --force can be used in manual gc
			 * after the user verifies that no gc is
			 * running.
			 */
			time(NULL) - st.st_mtime <= 12 * 3600 &&
			fscanf(fp, scan_fmt, &pid, locking_host) == 2 &&
			/* be gentle to concurrent "gc" on remote hosts */
			(strcmp(locking_host, my_host) || !kill(pid, 0) || errno == EPERM);
		if (fp != NULL)
			fclose(fp);
		if (should_exit) {
			if (fd >= 0)
				rollback_lock_file(&lock);
			*ret_pid = pid;
			free(pidfile_path);
			return locking_host;
		}
	}

	strbuf_addf(&sb, "%"PRIuMAX" %s",
		    (uintmax_t) getpid(), my_host);
	write_in_full(fd, sb.buf, sb.len);
	strbuf_release(&sb);
	commit_lock_file(&lock);
	pidfile = register_tempfile(pidfile_path);
	free(pidfile_path);
	return NULL;
}

int cmd_decrypt(int argc, const char **argv, const char *prefix)
{
	int aggressive = 0;
	int quiet = 0;
	int force = 0;
	const char *name;
	pid_t pid;
	int daemonized = 0;

	struct option builtin_gc_options[] = {
		OPT__QUIET(&quiet, N_("suppress progress reporting")),
		OPT_BOOL(0, "aggressive", &aggressive, N_("be more thorough (increased runtime)")),
		OPT_BOOL_F(0, "force", &force,
			   N_("force running decrypt even if there may be another decrypt running"),
			   PARSE_OPT_NOCOMPLETE),
		OPT_END()
	};

	if (argc == 2 && !strcmp(argv[1], "-h"))
		usage_with_options(builtin_decrypt_usage, builtin_gc_options);
	strvec_pushl(&repack, "repack", "-a", "-d", "-l", "--keep-unreachable", NULL);

	/* default expiry time, overwritten in decrypt_config */
	decrypt_config();

	argc = parse_options(argc, argv, prefix, builtin_gc_options,
			     builtin_decrypt_usage, 0);
	if (argc > 0)
		usage_with_options(builtin_decrypt_usage, builtin_gc_options);

	if (aggressive) {
		strvec_push(&repack, "-f");
		if (aggressive_depth > 0)
			strvec_pushf(&repack, "--depth=%d", aggressive_depth);
		if (aggressive_window > 0)
			strvec_pushf(&repack, "--window=%d", aggressive_window);
	}
	if (quiet)
		strvec_push(&repack, "-q");

	name = lock_repo_for_gc(force, &pid);
	if (name) {
		die(_("gc is already running on machine '%s' pid %"PRIuMAX" (use --force if not)"),
		    name, (uintmax_t)pid);
	}

	if (daemonized) {
		hold_lock_file_for_update(&log_lock,
					  git_path("gc.log"),
					  LOCK_DIE_ON_ERROR);
		dup2(get_lock_file_fd(&log_lock), 2);
		sigchain_push_common(process_log_file_on_signal);
		atexit(process_log_file_at_exit);
	}

	if (!repository_format_precious_objects) {
		close_object_store(the_repository->objects);
		if (run_command_v_opt(repack.v, RUN_GIT_CMD))
			die(FAILED_RUN, repack.v[0]);
	}

	report_garbage = report_pack_garbage;
	reprepare_packed_git(the_repository);
	if (pack_garbage.nr > 0) {
		close_object_store(the_repository->objects);
		clean_pack_garbage();
	}

	prepare_repo_settings(the_repository);
	if (the_repository->settings.gc_write_commit_graph == 1)
		write_commit_graph_reachable(the_repository->objects->odb,
					     !quiet && !daemonized ? COMMIT_GRAPH_WRITE_PROGRESS : 0,
					     NULL);

	if (!daemonized)
		unlink(git_path("gc.log"));

	return 0;
}
