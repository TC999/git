#ifndef ATTACH_H
#define ATTACH_H

/*
 * Return the default attachments ref.
 *
 * This the first of the following to be defined:
 * 1. The '--ref' option to 'git attach', if given
 * 2. The $GIT_ATTACHMENTS_REF environment variable, if set
 * 3. The value of the core.attachmentsRef config variable, if set
 * 4. GIT_NOTES_DEFAULT_REF (i.e. "refs/attachments/commits")
 */
const char *default_attachments_ref(void);

#endif
