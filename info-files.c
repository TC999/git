#include "cache.h"
#include "lockfile.h"
#include "info-files.h"

int create_info_file(struct lock_file *lk, const char *file)
{
	struct strbuf path = STRBUF_INIT;

	strbuf_addstr(&path, get_object_directory());

	/* create info dir if not exists */
	strbuf_addstr(&path, "/info");
	safe_create_dir(path.buf, 1);

	/* create info/large-blobs */
	strbuf_addf(&path, "/%s", file);
	hold_lock_file_for_update_mode(lk, path.buf, LOCK_DIE_ON_ERROR, 0444);

	strbuf_release(&path);

	return get_lock_file_fd(lk);
}
