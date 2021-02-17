#include "test-tool.h"
#include "cache.h"
#include "config.h"
#include "delta.h"
#include "pack.h"
#include "csum-file.h"
#include "blob.h"
#include "commit.h"
#include "tag.h"
#include "tree.h"
#include "progress.h"
#include "fsck.h"
#include "exec-cmd.h"
#include "streaming.h"
#include "thread-utils.h"
#include "packfile.h"
#include "object-store.h"
#include "parse-options.h"

static int input_fd;
static git_hash_ctx input_ctx;
static uint32_t input_crc32;

static unsigned char input_buffer[4096];
static unsigned char decrypt_buffer[4096];
static unsigned int input_offset, input_len;
static off_t consumed_bytes;
static off_t max_input_size;
static git_cryptor cryptor;
static int pack_is_encrypted;
static size_t in_pack_hdr_size;

static struct object_entry *objects;
static int nr_objects;

static int verbose;
static int show_crc;
static int show_size = 1;
static int show_version = 1;
static int show_offset = 1;

static const char * const agit_pack_usage[] = {
	"test-tool agit-inspect pack <pack-file>",
	NULL
};

struct object_entry {
	struct pack_idx_entry idx;
	unsigned long size;
	unsigned char hdr_size;
	signed char type;
	signed char real_type;
};

/* Discard current buffer used content. */
static void do_flush(int try_encrypt)
{
	if (input_offset) {
		/* Calculate checksum based on raw data from packfile. */
		the_hash_algo->update_fn(&input_ctx, input_buffer, input_offset);
		memmove(input_buffer, input_buffer + input_offset, input_len);
		if (pack_is_encrypted)
			memmove(decrypt_buffer, decrypt_buffer + input_offset, input_len);
		input_offset = 0;
	}
}

static void flush(void)
{
	do_flush(1);
}

static void flush_header(void)
{
	/* Calculate checksum based on raw data from packfile. */
	the_hash_algo->update_fn(&input_ctx, input_buffer, in_pack_hdr_size);

	input_offset = 0;
	input_len = 0;
	consumed_bytes += in_pack_hdr_size;
}

static void use(int bytes)
{
	if (bytes > input_len)
		die(_("used more bytes than were available"));
	input_crc32 = crc32(input_crc32, input_buffer + input_offset, bytes);
	input_len -= bytes;
	input_offset += bytes;

	/* make sure off_t is sufficiently large not to wrap */
	if (signed_add_overflows(consumed_bytes, bytes))
		die(_("pack too large for current definition of off_t"));
	consumed_bytes += bytes;
	if (max_input_size && consumed_bytes > max_input_size)
		die(_("pack exceeds maximum allowed size"));
}

static void setup_buffers_from_header(void)
{
	union extend_pack_header *input_hdr;
	struct pack_header *decrypt_hdr;

	input_hdr = (union extend_pack_header *)input_buffer;
	/* Header consistency check */
	if (input_hdr->hdr.hdr_signature != htonl(PACK_SIGNATURE))
		die(_("pack signature mismatch"));
	if (!pack_version_ok(input_hdr->hdr.hdr_version))
		die(_("pack version %"PRIu32" unsupported"),
			ntohl(input_hdr->hdr.hdr_version));
	nr_objects = ntohl(input_hdr->hdr.hdr_entries);

	if (git_crypto_pack_is_encrypt(input_hdr->hdr.hdr_version)) {
		pack_is_encrypted = 1;
		if (crypto_pack_has_longer_nonce_for_version(
			    input_hdr->hdr.hdr_version)) {
			in_pack_hdr_size = sizeof(struct pack_header_with_nonce);
			git_decryptor_init_or_die(&cryptor,
						  input_hdr->ehdr.hdr_version,
						  input_hdr->ehdr.nonce);
		} else {
			in_pack_hdr_size = sizeof(struct pack_header);
			git_decryptor_init_or_die(
				&cryptor, input_hdr->ehdr.hdr_version, NULL);
		}
		cryptor.byte_counter = in_pack_hdr_size;
	} else {
		in_pack_hdr_size = sizeof(struct pack_header);
	}
	if (pack_is_encrypted) {
		decrypt_hdr = (struct pack_header *)decrypt_buffer;
		memcpy(decrypt_hdr, input_hdr, sizeof(*decrypt_hdr));
		decrypt_hdr->hdr_version = (decrypt_hdr->hdr_version >> 24) << 24;
	}
}

/*
 * Make sure at least "min" bytes are available in the buffer, and
 * return the pointer to the buffer.
 */
static void *fill(int min)
{
	if (min <= input_len) {
		if (pack_is_encrypted)
			return decrypt_buffer + input_offset;
		else
			return input_buffer + input_offset;
	}
	if (min > sizeof(input_buffer))
		die(Q_("cannot fill %d byte",
		       "cannot fill %d bytes",
		       min),
		    min);
	flush();
	do {
		ssize_t ret = xread(input_fd, input_buffer + input_len,
				sizeof(input_buffer) - input_len);
		if (ret <= 0) {
			if (!ret)
				die(_("early EOF"));
			die_errno(_("read error on input"));
		}
		if (pack_is_encrypted)
			cryptor.decrypt(&cryptor,
					  input_buffer + input_len,
					  decrypt_buffer + input_len,
					  ret,
					  ret);
		input_len += ret;
	} while (input_len < min);
	if (pack_is_encrypted)
		return decrypt_buffer;
	else
		return input_buffer;
}

static void open_pack_file(const char *pack_name)
{
	input_fd = xopen(pack_name, O_RDONLY);
	the_hash_algo->init_fn(&input_ctx);
}

static void parse_pack_header(void)
{
	union extend_pack_header *hdr;
	int hdr_size = sizeof(struct pack_header);
	struct strbuf msg = STRBUF_INIT;
	uint32_t hdr_version;

	/* Header maybe provided by command line option: --pack_header=... */
	if (input_len == 0) {
		ssize_t ret = read_in_full(input_fd, input_buffer, hdr_size);
		if (ret <= 0) {
			if (!ret)
				die(_("early EOF"));
			die_errno(_("read error on input"));
		}
		input_len += ret;
	}

	hdr = (union extend_pack_header *) input_buffer;
	if (git_crypto_pack_is_encrypt(hdr->hdr.hdr_version) &&
	    crypto_pack_has_longer_nonce_for_version(
		    hdr->hdr.hdr_version)) {
		ssize_t ret = read_in_full(input_fd, input_buffer + input_len,
					   sizeof(struct pack_header_with_nonce) - input_len);
		if (ret <= 0) {
			if (!ret)
				die(_("early EOF"));
			die_errno(_("read error on input"));
		}
		input_len += ret;
	}

	/* Filling header */
	setup_buffers_from_header();

	hdr_version = hdr->hdr.hdr_version;

	flush_header();

	strbuf_addf(&msg, "Header: %s", pack_is_encrypted ? "encrypt": "plain");
	if (pack_is_encrypted) {
		strbuf_addf(&msg, " (%x)", cryptor.algorithm);
	}
	if (show_version)
		strbuf_addf(&msg, ", version: %08"PRIx32, ntohl(hdr_version));
	strbuf_addch(&msg, '\n');
	strbuf_addf(&msg, "Number of objects: %d\n", nr_objects);
	printf("%s\n", msg.buf);
	strbuf_release(&msg);
}

static NORETURN void bad_object(off_t offset, const char *format,
		       ...) __attribute__((format (printf, 2, 3)));

static NORETURN void bad_object(off_t offset, const char *format, ...)
{
	va_list params;
	char buf[1024];

	va_start(params, format);
	vsnprintf(buf, sizeof(buf), format, params);
	va_end(params);
	die(_("pack has bad object at offset %"PRIuMAX": %s"),
	    (uintmax_t)offset, buf);
}

static void *unpack_entry_data(off_t offset, unsigned long size,
			       enum object_type type, struct object_id *oid)
{
	static char fixed_buf[8192];
	int status;
	git_zstream stream;
	void *buf;

	if (type == OBJ_BLOB && size > big_file_threshold)
		buf = fixed_buf;
	else
		buf = xmallocz(size);

	memset(&stream, 0, sizeof(stream));
	git_inflate_init(&stream);
	stream.next_out = buf;
	stream.avail_out = buf == fixed_buf ? sizeof(fixed_buf) : size;

	do {
		stream.next_in = fill(1);
		stream.avail_in = input_len;
		status = git_inflate(&stream, 0);
		use(input_len - stream.avail_in);
		if (buf == fixed_buf) {
			stream.next_out = buf;
			stream.avail_out = sizeof(fixed_buf);
		}
	} while (status == Z_OK || status == Z_BUF_ERROR);
	if (stream.total_out != size || status != Z_STREAM_END)
		bad_object(offset, _("inflate returned %d"), status);
	git_inflate_end(&stream);
	return buf == fixed_buf ? NULL : buf;
}

static void *unpack_raw_entry(struct object_entry *obj,
			      off_t *ofs_offset,
			      struct object_id *ref_oid,
			      struct object_id *oid)
{
	unsigned char *p;
	unsigned long size, c;
	off_t base_offset;
	unsigned shift;
	void *data;

	obj->idx.offset = consumed_bytes;
	input_crc32 = crc32(0, NULL, 0);

	p = fill(1);
	c = *p;
	use(1);
	obj->type = (c >> 4) & 7;
	size = (c & 15);
	shift = 4;
	while (c & 0x80) {
		p = fill(1);
		c = *p;
		use(1);
		size += (c & 0x7f) << shift;
		shift += 7;
	}
	obj->size = size;

	switch (obj->type) {
	case OBJ_REF_DELTA:
		hashcpy(ref_oid->hash, fill(the_hash_algo->rawsz));
		use(the_hash_algo->rawsz);
		break;
	case OBJ_OFS_DELTA:
		p = fill(1);
		c = *p;
		use(1);
		base_offset = c & 127;
		while (c & 128) {
			base_offset += 1;
			if (!base_offset || MSB(base_offset, 7))
				bad_object(obj->idx.offset, _("offset value overflow for delta base object"));
			p = fill(1);
			c = *p;
			use(1);
			base_offset = (base_offset << 7) + (c & 127);
		}
		*ofs_offset = obj->idx.offset - base_offset;
		if (*ofs_offset <= 0 || *ofs_offset >= obj->idx.offset)
			bad_object(obj->idx.offset, _("delta base offset is out of bound"));
		break;
	case OBJ_COMMIT:
	case OBJ_TREE:
	case OBJ_BLOB:
	case OBJ_TAG:
		break;
	default:
		bad_object(obj->idx.offset, _("unknown object type %d"), obj->type);
	}
	obj->hdr_size = consumed_bytes - obj->idx.offset;

	data = unpack_entry_data(obj->idx.offset, obj->size, obj->type, oid);
	obj->idx.crc32 = input_crc32;
	return data;
}

/*
 * First pass:
 * - find locations of all objects;
 * - calculate SHA1 of all non-delta objects;
 * - remember base (SHA1 or offset) for all deltas.
 */
static void parse_pack_objects(unsigned char *hash)
{
	int i;
	struct object_id ref_delta_oid;
	unsigned char *fill_hash;
	struct strbuf msg = STRBUF_INIT;

	for (i = 0; i < nr_objects; i++) {
		struct object_entry *obj = &objects[i];
		off_t ofs_delta_offset = 0;

		void *data = unpack_raw_entry(obj, &ofs_delta_offset,
					      &ref_delta_oid,
					      &obj->idx.oid);
		strbuf_reset(&msg);
		strbuf_addf(&msg, "[obj %d] ", i + 1);
		switch(obj->type) {
		case OBJ_OFS_DELTA:
			strbuf_addstr(&msg, "type: ofs-delta");
			if (show_offset)
				strbuf_addf(&msg, " (offset: %"PRId64")", ofs_delta_offset);
			break;
		case OBJ_REF_DELTA:
			strbuf_addstr(&msg, "type: ref-delta");
			if (show_offset)
				strbuf_addf(&msg, " (refoid: %s)", oid_to_hex(&ref_delta_oid));
			break;
		case OBJ_COMMIT:
			strbuf_addstr(&msg, "type: commit");
			break;
		case OBJ_TREE:
			strbuf_addstr(&msg, "type: tree");
			break;
		case OBJ_BLOB:
			strbuf_addstr(&msg, "type: blob");
			break;
		case OBJ_TAG:
			strbuf_addstr(&msg, "type: tag");
			break;
		default:
			strbuf_addf(&msg, "type: unknown (%d)", obj->type);
		}
		if (show_size)
			strbuf_addf(&msg, ", size: %ld", obj->size);
		if (show_crc)
			strbuf_addf(&msg, ", crc32: %8x", obj->idx.crc32);
		printf("%s\n", msg.buf);
		free(data);
	}
	objects[i].idx.offset = consumed_bytes;

	/* Check pack integrity */
	flush();
	the_hash_algo->final_fn(hash, &input_ctx);
	fill_hash = fill(the_hash_algo->rawsz);
	if (pack_is_encrypted) {
		/* The checksum at the end of packfile is unencrypted, but
		 * after call fill, the hash is mangled, and should be
		 * restored by calling decrypt again.
		 */
		cryptor.byte_counter -= the_hash_algo->rawsz;
		cryptor.decrypt(&cryptor, fill_hash, fill_hash,
				  the_hash_algo->rawsz, the_hash_algo->rawsz);
	}
	if (!hasheq(fill_hash, hash))
		fprintf(stderr, "ERROR: pack is corrupted (checksum mismatch)");
	else
		printf("\nChecksum OK.\n");

	use(the_hash_algo->rawsz);
}

static int inspect_pack(const char *pack_name)
{
	unsigned char pack_hash[GIT_MAX_RAWSZ];

	open_pack_file(pack_name);
	parse_pack_header();
	CALLOC_ARRAY(objects, st_add(nr_objects, 1));
	parse_pack_objects(pack_hash);
	return 0;
}

int cmd__agit_inspect(int argc, const char *argv[])
{
	const char *cmd = NULL;
	const char *pack_name = NULL;
	int i;
	const struct option agit_pack_options[] = {
		OPT_BOOL('v', "verbose", &verbose, N_("verbose")), 
		OPT_BOOL(0, "show-crc", &show_crc, "show entry crc32"),
		OPT_BOOL(0, "show-size", &show_size, "show entry size"),
		OPT_BOOL(0, "show-offset", &show_offset, "show delta object offset"),
		OPT_BOOL(0, "show-version", &show_version, "show packfile version"),
		OPT_END()
	};

	setup_git_directory();
	git_config(git_default_config, NULL);
	argc = parse_options(argc, argv, NULL, agit_pack_options,
			     agit_pack_usage, 0);
	for (i = 0; i < argc; i++) {
		if (!cmd)
			cmd = argv[i];
		else if (!pack_name)
			pack_name = argv[i];
		else
			usage_with_options(agit_pack_usage, agit_pack_options);
	}

	if (!cmd || !pack_name)
		usage_with_options(agit_pack_usage, agit_pack_options);

	if (!strcmp(cmd, "pack"))
		return inspect_pack(pack_name);
	else {
		error("bad command: %s\n", cmd);
		usage_with_options(agit_pack_usage, agit_pack_options);
	}

	return 1;
}
