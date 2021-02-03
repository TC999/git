#include "test-tool.h"
#include "cache.h"
#include "trace.h"
#include "crypto.h"

#define INPUT_BUF_SIZE 4096

static git_cryptor cryptor;
static int use_mmap = 0;

/*
 * Compress stream from in to out, and encrypt if agit_crypt_enabled is true.
 * 1. Add encrypt header for out if agit_crypto_enabled.
 * 2. Deflate
 * 3. Encrypt stream
 */
static int do_deflate(int in, int out, size_t total)
{
	git_zstream strm;
	unsigned char *map = NULL;
	unsigned char buf[4096];
	ssize_t size;
	int flush = 0;
	int ret;

	if (use_mmap) {
		/* read or mmap file to buffer */
		map = mmap(NULL, total, PROT_READ, MAP_PRIVATE, in, 0);
		if (map == MAP_FAILED)
			die("mmap failed");
		size = total;
	} else {
		map = malloc(INPUT_BUF_SIZE);
		size = read(in, map, INPUT_BUF_SIZE);
		if (size < 0)
			die("fail to read input file");
	}

	/* Encrypt: init crypto, and write header */
	if (agit_crypto_enabled) {
		unsigned char *header = NULL;

		git_encryptor_init_for_loose_object(&cryptor);
		header = git_encryptor_get_net_object_header(&cryptor, NULL);
		if (write(out, header, GIT_CRYPTO_LO_HEADER_SIZE) < 0)
			die(_("unable to write loose object file"));
		free(header);
	}

	/* Set it up */
	git_deflate_init(&strm, zlib_compression_level);
	strm.next_in = (unsigned char *)map;
	strm.avail_in = size;
	strm.next_out = buf;
	strm.avail_out = sizeof(buf);
	if (agit_crypto_enabled)
		strm.cryptor = &cryptor;

	do {
		size_t len;

		if (use_mmap) {
			flush = Z_FINISH;
			ret = git_deflate(&strm, flush);
		} else {
			ret = git_deflate(&strm, flush);

			if (strm.avail_in == 0) {
				size = read(in, map, INPUT_BUF_SIZE);
				if (size < 0)
					die("fail to read input file");
				strm.next_in= map;
				strm.avail_in = size;
				if (size == 0) {
					flush = Z_FINISH;
					trace_printf_key(&trace_crypto_key,
						"debug: deflate set flush to %d"
						", avail_in: %ld"
						", avail_out: %ld"
						", total_in: %ld"
						", total_out: %ld"
						"\n",
						flush,
						strm.avail_in,
						strm.avail_out,
						strm.total_in,
						strm.total_out);
				}
			}
		}
		len = strm.next_out - buf;
		if (len > 0) {
			if (write(out, buf, len) != len)
				die("unable to write output");
		}
		strm.next_out = buf;
		strm.avail_out = sizeof(buf);
		if (ret == Z_BUF_ERROR)
			trace_printf_key(&trace_crypto_key, "debug: deflate finds Z_BUF_ERROR\n");
	} while (ret == Z_OK || ret == Z_BUF_ERROR);

	if (ret != Z_STREAM_END)
		die("unable to deflate (%d)", ret);
	ret = git_deflate_end_gently(&strm);
	if (ret != Z_OK)
		die("deflateEnd failed (%d)", ret);
	if (use_mmap)
		munmap(map, total);
	else
		free(map);
	return 0;
}

/*
 * Uncompress stream from in to out, and decrypt if has proper header.
 * 1. Read header from input, and check if it is encrypted stream.
 * 2. Decrypt
 * 3. Inflate
 */
static int do_inflate(int in, int out, size_t total)
{
	git_zstream strm;
	unsigned char *map = NULL;
	unsigned char buf[4096];
	ssize_t size;
	int flush = 0;
	int encrypted = 0;
	int ret;

	if (use_mmap) {
		/* read or mmap file to buffer */
		map = mmap(NULL, total, PROT_READ, MAP_PRIVATE, in, 0);
		if (map == MAP_FAILED)
			die("mmap failed");
		size = total;
	} else {
		map = malloc(INPUT_BUF_SIZE);
		if (!map)
			die("fail to allocate map for input buf");
		size = read(in, map, INPUT_BUF_SIZE);
		if (size < 0)
			die("fail to read input file");
	}

	if (size == total)
		flush = Z_FINISH;

	/* Decrypt: check object header */
	if (size > GIT_CRYPTO_LO_HEADER_SIZE &&
	    git_crypto_lo_has_signature(map)) {
		encrypted = 1;
		git_decryptor_init_or_die(&cryptor, *(unsigned int *)(map + 4),
					  map + 8);
	}

	/* Set it up */
	memset(&strm, 0, sizeof(strm));
	if (encrypted) {
		strm.cryptor = &cryptor;
		strm.next_in = map + GIT_CRYPTO_LO_HEADER_SIZE;
		strm.avail_in = size - GIT_CRYPTO_LO_HEADER_SIZE;
	} else {
		strm.next_in = map;
		strm.avail_in = size;
	}
	strm.next_out = buf;
	strm.avail_out = sizeof(buf);
	git_inflate_init(&strm);

	do {
		size_t len;
		unsigned char *phead = strm.next_out;

		ret = git_inflate(&strm, flush);
		len = strm.next_out - phead;
		if (len > 0) {
			if (write(out, buf, len) < 0)
				die("unable to write output");
		}
		strm.next_out = buf;
		strm.avail_out = sizeof(buf);

		if (strm.avail_in == 0 && !use_mmap) {
			size = read(in, map, INPUT_BUF_SIZE);
			/* EOF */
			if (size == 0) {
				flush = Z_FINISH;
				trace_printf_key(&trace_crypto_key,
					"debug: inflate set flush to %d"
					", avail_in: %ld"
					", avail_out: %ld"
					", total_in: %ld"
					", total_out: %ld"
					"\n",
					flush,
					strm.avail_in,
					strm.avail_out,
					strm.total_in,
					strm.total_out);
			} else if (size < 0) {
				die("fail to read input file");
			} else {
				strm.next_in = map;
				strm.avail_in = size;
			}
		}

		if (ret == Z_BUF_ERROR)
			trace_printf_key(&trace_crypto_key, "debug: inflate finds Z_BUF_ERROR\n");
	} while (ret == Z_OK || ret == Z_BUF_ERROR);
	/* NOTE: ret may encounter Z_BUF_ERROR, but we do not need to increate buffer, just try again */

	if (ret != Z_STREAM_END)
		die("unable to inflate (%d)", ret);
	git_inflate_end(&strm);

	if (use_mmap)
		munmap(map, total);
	else
		free(map);
	return 0;
}

static int agit_crypto_usage(char *fmt, ...)
{
	struct strbuf buf = STRBUF_INIT;
	va_list ap;
	va_start(ap, fmt);

	strbuf_vaddf(&buf, fmt, ap);
	fprintf(stderr, "zlib inflate/deflate demo\n\n");
	fprintf(stderr, "Usage:\n");
	fprintf(stderr, "\ttest-tool agit-crypto [-z | -x] [--secret <token>] -i <input-file> -o <output-file>\n");
	if (buf.len)
		fprintf(stderr, "\nERROR: %s\n", buf.buf);
	strbuf_release(&buf);
	return 1;
}

int cmd__agit_crypto(int argc, const char *argv[])
{
	char *in = NULL;
	char *out = NULL;
	int fdin, fdout;
	int inflate = -1;
	int ret = 0;
	struct stat st;
	int i;

	for (i = 1; i < argc; i++) {
		if (!strcmp("-i", argv[i])) {
			i++;
			in = strdup(argv[i]);
		} else if (!strcmp("-o", argv[i])) {
			i++;
			out = strdup(argv[i]);
		} else if (!strcmp("-x", argv[i])) {
			inflate = 1;
		} else if (!strcmp("-z", argv[i])) {
			inflate = 0;
		} else if (!strcmp("--secret", argv[i])) {
			agit_crypto_secret = strdup(argv[++i]);
			agit_crypto_enabled = 1;
			agit_crypto_nonce = "random_nonce";
		} else if (!strcmp("--mmap", argv[i])) {
			use_mmap = 1;
		} else {
			return agit_crypto_usage("unknown option: %s", argv[i]);
		}
	}

	if (inflate == -1)
		return agit_crypto_usage("-z or -x is not provided");
	if (!in)
		return agit_crypto_usage("must provide -i <input>");
	if (!out)
		return agit_crypto_usage("must provide -o <output>");
	if (!strcmp(in, out))
		return agit_crypto_usage("in and out file cannot be the same one");

	if (!strcmp(in, "-")) {
		fdin = fileno(stdin);
	} else {
		fdin = xopen(in, O_RDONLY);
	}
	if (!strcmp(out, "-")) {
		fdout = fileno(stdout);
	} else {
		fdout = xopen(out, O_RDWR | O_CREAT | O_TRUNC, 0644);
	}

	if (fstat(fdin, &st))
		die("fail to get size of file %s", in);

	if (inflate)
		ret = do_inflate(fdin, fdout, st.st_size);
	else
		ret = do_deflate(fdin, fdout, st.st_size);

	close(fdin);
	close(fdout);

	if (inflate)
		printf("unzip file '%s' to '%s'\n", in, out);
	else
		printf("zip file '%s' to '%s'\n", in, out);

	return ret;
}
