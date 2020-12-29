#include "test-tool.h"
#include "cache.h"

#define INPUT_BUF_SIZE 4096

int cmd__agit_od(int argc, const char *argv[])
{
	struct strbuf buf = STRBUF_INIT;
	struct strbuf asc_buf = STRBUF_INIT;
	unsigned char line[INPUT_BUF_SIZE];
	unsigned char *p;
	ssize_t len;
	size_t i;
	int show_ascii = 1;

	for (i = 1; i < argc; i++) {
		if (!strcmp("--no-ascii", argv[i])) {
			show_ascii = 0;
		} else if (!strcmp("--ascii", argv[i])) {
			show_ascii = 1;
		}
	}

	while (1) {

		len = read(0, line, INPUT_BUF_SIZE);
		if (len < 0)
			die("fail to read");
		if (len == 0)
			break;
		p = line;

		for (i = 0; i < len; i++, p++) {
			if (i % 16 == 0) {
				if (i > 0) {
					if (show_ascii) {
						printf("%-55s    | %-16s |\n", buf.buf, asc_buf.buf);
						strbuf_reset(&asc_buf);
					} else {
						printf("%s\n", buf.buf);
					}
				}
				strbuf_reset(&buf);
				strbuf_addf(&buf, "%07"PRIuPTR, i);
			}
			strbuf_addf(&buf, " %02x", *p);
			if (show_ascii) {
				if (isspace(*p))
					strbuf_addch(&asc_buf, ' ');
				else
					strbuf_addch(&asc_buf, isprint(*p) ? *p : '.');
			}
		}
	}
	if (buf.len) {
		if (show_ascii)
			printf("%-55s    | %-16s |\n", buf.buf, asc_buf.buf);
		else
			printf("%s\n", buf.buf);
	}

	strbuf_release(&buf);
	strbuf_release(&asc_buf);

	return 0;
}

