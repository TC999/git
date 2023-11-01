#include "git-compat-util.h"
#include "environment.h"
#include "attach.h"

const char *default_attachments_ref(void)
{
        const char *attachments_ref = NULL;
        if (!attachments_ref)
                attachments_ref = getenv(GIT_ATTACHMENTS_REF_ENVIRONMENT);
        if (!attachments_ref)
                attachments_ref = attachments_ref_name;
        if (!attachments_ref)
                attachments_ref = GIT_ATTACHMENTS_DEFAULT_REF;
        return attachments_ref;
}
