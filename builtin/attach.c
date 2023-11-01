#include "builtin.h"
#include "gettext.h"
#include "parse-options.h"
#include "config.h"
#include "pathspec.h"
#include "setup.h"
#include "object-store.h"
#include "object-file.h"
#include "object-name.h"
#include "hex.h"
#include "attach.h"
#include "refs.h"
#include "tree-walk.h"
#include "tree.h"
#include "dir-iterator.h"
#include "iterator.h"

static const char * const git_attach_usage[] = {
	N_("git attach add [--commitish] <file>"),
	NULL
};

static const char *const git_attach_add_usage[] = { 
	N_("git attach add [--commitish] <file>"),
	NULL
};

static int write_attach_ref(const char *ref, struct object_id *attach_tree,
			    const char *msg)
{
	const char *attachments_ref;
	struct object_id commit_oid;
	struct object_id parent_oid;
	struct tree_desc desc;
	struct name_entry entry;
	struct tree *tree = NULL;
	struct commit_list *parents = NULL;
	struct strbuf buf = STRBUF_INIT;

	if (!ref)
		attachments_ref = default_attachments_ref();

	if (!read_ref(attachments_ref, &parent_oid)) {
		struct commit *parent = lookup_commit(the_repository, &parent_oid);
		if (repo_parse_commit(the_repository, parent))
			die("Failed to find/parse commit %s", attachments_ref);
		commit_list_insert(parent, &parents);
	}

	tree = repo_get_commit_tree(the_repository,
				    lookup_commit(the_repository, &parent_oid));
	init_tree_desc(&desc, tree->buffer, tree->size);

	while (tree_entry(&desc, &entry)) {
		switch (object_type(entry.mode)) {
		case OBJ_TREE:
			fprintf(stderr, "entry.path: %s\n", entry.path);
			continue;
		default:
			continue;
		}
	}

	if (commit_tree(msg, strlen(msg), attach_tree, parents, &commit_oid,
			NULL, NULL))
		die(_("failed to commit attachment tree to database"));

	strbuf_addstr(&buf, msg);
	update_ref(buf.buf, attachments_ref, &commit_oid, NULL, 0,
		   UPDATE_REFS_DIE_ON_ERR);

	strbuf_release(&buf);
	return 0;
}

static int deal_blob(struct strbuf *tree_buf, const char *name)
{
	struct object_id oid;
	struct strbuf buf = STRBUF_INIT;

	if (strbuf_read_file(&buf, name, 0) < 0)
		die(_("unable to read regular file '%s'"), name);

	if (write_object_file_flags(buf.buf, buf.len, OBJ_BLOB, &oid,
				    HASH_FORMAT_CHECK | HASH_WRITE_OBJECT))
		die(_("unable to add blob from %s to database"), name);

	strbuf_addf(tree_buf, "%o %s%c", 0100644, name, '\0');
	strbuf_add(tree_buf, oid.hash, the_hash_algo->rawsz);
	strbuf_release(&buf);
	return 0;
}

static int deal_tree(struct strbuf *parent_tree_buf, const char *dir_name)

{
	struct dir_iterator *iter;
	int iter_status;
	struct object_id tree;
	struct strbuf tree_buf = STRBUF_INIT;
	struct dir_struct dir = DIR_INIT;

	iter = dir_iterator_begin(dir_name, DIR_ITERATOR_PEDANTIC);

	if (!iter)
		die_errno(_("failed to start iterator over '%s'"), dir_name);
	while ((iter_status = dir_iterator_advance(iter)) == ITER_OK) {
		if (iter->st.st_mode & S_IFDIR) {
			deal_tree(iter->path.buf, &tree_buf);
		} else if (iter->st.st_mode & S_IFREG) {
			deal_blob(&tree_buf, iter->basename);
		} else {
			die(_("unsupported file type '%s', mode: '%o'"),
			    iter->relative_path, iter->st.st_mode);
		}
	}

	strbuf_addf(parent_tree_buf, "%o %s%c", 040000, dir_name, '\0');
	strbuf_add(parent_tree_buf, tree.hash, the_hash_algo->rawsz);

	strbuf_release(&tree_buf);
	return 0;
}

static int write_attach_tree(const struct pathspec *pathspec,
			     struct object_id *attach_tree,
			     struct object_id *attach_commit)
{
	struct stat st;
	struct object_id tree_oid;
	struct strbuf tree_buf = STRBUF_INIT;
	struct strbuf attach_tree_buf = STRBUF_INIT;
	struct dir_struct dir = DIR_INIT;
	char *commit_oid = oid_to_hex(attach_commit);

	for (int i = 0; i < pathspec->nr; i++) {
		char *path = pathspec->items[i].original;
		if (lstat(path, &st))
			die_errno(_("fail to stat file '%s'"), path);
		if (S_ISREG(st.st_mode)) {
			deal_blob(&tree_buf, path);
		} else if (S_ISDIR(st.st_mode)) {
			deal_tree(path, &tree_buf);
		} else {
			die(_("unsupported file type '%s', mode: '%o'"), path,
			    st.st_mode);
		}
	}
	write_object_file(tree_buf.buf, tree_buf.len, OBJ_TREE, &tree_oid);

	strbuf_addf(&attach_tree_buf, "%o %s%c", 040000, commit_oid, '\0');
	strbuf_add(&attach_tree_buf, tree_oid.hash, the_hash_algo->rawsz);
	write_object_file(attach_tree_buf.buf, attach_tree_buf.len, OBJ_TREE,
			  attach_tree);

	strbuf_release(&tree_buf);
	strbuf_release(&attach_tree_buf);
	return 0;
}

static int add(int argc, const char **argv, const char *prefix)
{
	struct pathspec pathspec;
	struct object_id attach_tree;
	struct object_id attach_commit;
	char *attach_commitish = NULL;
	char *attachments_msg = "Attachments updated by 'git attach add'";

	struct option options[] = {
		OPT_STRING(0, "commit", &attach_commitish, N_("commit"),
			   N_("the commit which the attachments reference to")),
		OPT_END()
	};

	parse_options(argc, argv, prefix, options, git_attach_add_usage,
			     PARSE_OPT_KEEP_ARGV0);
	attach_commitish = attach_commitish ? attach_commitish : "HEAD";

	if (repo_get_oid_commit(the_repository, attach_commitish,
				&attach_commit))
		die(_("unable to find commit %s"), attach_commitish);

	parse_pathspec(&pathspec, 0,
		       PATHSPEC_PREFER_FULL | PATHSPEC_SYMLINK_LEADING_PATH,
		       prefix, argv + 1);
	if (!pathspec.nr)
		die(_("nothing specified, nothing to attach"));

	if (write_attach_tree(&pathspec, &attach_tree, &attach_commit))
		die(_("unable to write attach tree object"));

	if (write_attach_ref(NULL, &attach_tree, attachments_msg))
		die(_("unable to write attach ref"));

	clear_pathspec(&pathspec);
	return 0;
}

int cmd_attach(int argc, const char **argv, const char *prefix)
{
	parse_opt_subcommand_fn *fn = NULL;
	struct option options[] = { OPT_SUBCOMMAND("add", &fn, add),
				    OPT_END() };

	git_config(git_default_config, NULL);

	argc = parse_options(argc, argv, prefix, options, git_attach_usage,
			     PARSE_OPT_SUBCOMMAND_OPTIONAL);

	if (!fn) {
		error(_("subcommand `%s' not implement yet"), argv[0]);
		usage_with_options(git_attach_usage, options);
	}

	return !!fn(argc, argv, prefix);
}
