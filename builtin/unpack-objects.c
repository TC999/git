#include "builtin.h"
#include "cache.h"
#include "config.h"
#include "object-store.h"
#include "object.h"
#include "delta.h"
#include "pack.h"
#include "blob.h"
#include "commit.h"
#include "tag.h"
#include "tree.h"
#include "tree-walk.h"
#include "progress.h"
#include "decorate.h"
#include "fsck.h"

static int dry_run, quiet, recover, has_errors, strict;
static const char unpack_usage[] = "git unpack-objects [-n] [-q] [-r] [--strict]";

/* We always read in 4kB chunks. */
static unsigned char buffer[4096];
static unsigned char decrypt_buffer[4096];
static unsigned int offset, len;
static off_t consumed_bytes;
static off_t max_input_size;
static off_t max_input_object_size;
static off_t max_input_blob_size;
static git_hash_ctx ctx;
static struct fsck_options fsck_options = FSCK_OPTIONS_STRICT;
static struct progress *progress;
static struct git_cryptor cryptor_r;
static int pack_is_encrypted;

/*
 * When running under --strict mode, objects whose reachability are
 * suspect are kept in core without getting written in the object
 * store.
 */
struct obj_buffer {
	char *buffer;
	unsigned long size;
};

static struct decoration obj_decorate;

static struct obj_buffer *lookup_object_buffer(struct object *base)
{
	return lookup_decoration(&obj_decorate, base);
}

static void add_object_buffer(struct object *object, char *buffer, unsigned long size)
{
	struct obj_buffer *obj;
	CALLOC_ARRAY(obj, 1);
	obj->buffer = buffer;
	obj->size = size;
	if (add_decoration(&obj_decorate, object, obj))
		die("object %s tried to add buffer twice!", oid_to_hex(&object->oid));
}

/*
 * Make sure at least "min" bytes are available in the buffer, and
 * return the pointer to the buffer.
 */
static void *fill(int min)
{
	if (min <= len) {
		if (pack_is_encrypted)
			return decrypt_buffer + offset;
		else
			return buffer + offset;
	}
	if (min > sizeof(buffer))
		die("cannot fill %d bytes", min);
	if (offset) {
		/* Calculate checksum from raw data before decryption. */
		the_hash_algo->update_fn(&ctx, buffer, offset);
		memmove(buffer, buffer + offset, len);
		if (pack_is_encrypted)
			memmove(decrypt_buffer, decrypt_buffer + offset, len);
		offset = 0;
	}
	do {
		ssize_t ret = xread(0, buffer + len, sizeof(buffer) - len);
		if (ret <= 0) {
			if (!ret)
				die("early EOF");
			die_errno("read error on input");
		}
		/* Decrypt new raw data from stdin. */
		if (pack_is_encrypted)
			cryptor_r.decrypt(&cryptor_r, buffer + len,
					  decrypt_buffer + len, ret, ret);
		len += ret;
	} while (len < min);
	if (pack_is_encrypted)
		return decrypt_buffer;
	else
		return buffer;
}

static void use(int bytes)
{
	if (bytes > len)
		die("used more bytes than were available");
	len -= bytes;
	offset += bytes;

	/* make sure off_t is sufficiently large not to wrap */
	if (signed_add_overflows(consumed_bytes, bytes))
		die("pack too large for current definition of off_t");
	consumed_bytes += bytes;
	if (max_input_size && consumed_bytes > max_input_size)
		die(_("pack exceeds maximum allowed size"));
	display_throughput(progress, consumed_bytes);
}

static void *get_data(unsigned long size, int dry_run)
{
	git_zstream stream;
	unsigned long bufsize = dry_run ? 8192 : size;
	void *buf = xmallocz(bufsize);

	memset(&stream, 0, sizeof(stream));

	stream.next_out = buf;
	stream.avail_out = bufsize;
	stream.next_in = fill(1);
	stream.avail_in = len;
	git_inflate_init(&stream);

	for (;;) {
		int ret = git_inflate(&stream, 0);
		use(len - stream.avail_in);
		if (stream.total_out == size && ret == Z_STREAM_END)
			break;
		if (ret != Z_OK) {
			error("inflate returned %d", ret);
			FREE_AND_NULL(buf);
			if (!recover)
				exit(1);
			has_errors = 1;
			break;
		}
		stream.next_in = fill(1);
		stream.avail_in = len;
		if (dry_run) {
			/* reuse the buffer in dry_run mode */
			stream.next_out = buf;
			stream.avail_out = bufsize;
		}
	}
	git_inflate_end(&stream);
	return buf;
}

struct delta_info {
	struct object_id base_oid;
	unsigned nr;
	off_t base_offset;
	unsigned long size;
	void *delta;
	struct delta_info *next;
};

static struct delta_info *delta_list;

static void add_delta_to_list(unsigned nr, const struct object_id *base_oid,
			      off_t base_offset,
			      void *delta, unsigned long size)
{
	struct delta_info *info = xmalloc(sizeof(*info));

	oidcpy(&info->base_oid, base_oid);
	info->base_offset = base_offset;
	info->size = size;
	info->delta = delta;
	info->nr = nr;
	info->next = delta_list;
	delta_list = info;
}

struct obj_info {
	off_t offset;
	struct object_id oid;
	struct object *obj;
};

/* Remember to update object flag allocation in object.h */
#define FLAG_OPEN (1u<<20)
#define FLAG_WRITTEN (1u<<21)

static struct obj_info *obj_list;
static unsigned nr_objects;

/*
 * Return plain pack header and try to decrypt remain data in buffer.
 */
static void fill_header(void)
{
	struct pack_header *hdr;
	unsigned char *in;
	int hdr_size = sizeof(struct pack_header);
	uint32_t hdr_version;

	/* If has option "--pack_header=" in command line, header is already
	 * given and fill the buffer.
	 *
	 * The first time we call fill() will try to read more data to fill
	 * the whole buffer, which contains not only the plain header, but
	 * also the un-decrypted data, which should be decrypted if packfile
	 * is encrypted.
	 */
	in = fill(hdr_size);
	/* 'pack_is_encrypted' should be set here only, */
	assert(pack_is_encrypted == 0);
	/* and 'in' should always points to input_buffer. */
	assert(in == buffer);

	hdr = (struct pack_header *)in;
	nr_objects = ntohl(hdr->hdr_entries);
	hdr_version = hdr->hdr_version;
	if (ntohl(hdr->hdr_signature) != PACK_SIGNATURE)
		die("bad pack file");
	if (!pack_version_ok(hdr_version))
		die("unknown pack file version %"PRIu32,
			ntohl(hdr_version));
	use(hdr_size);
	if (git_crypto_pack_is_encrypt(hdr_version)) {
		if (crypto_pack_has_longer_nonce_for_version(hdr_version)) {
			/* Read nonce from raw input. */
			in = fill(NONCE_LEN);

			/* Setup cryptor after fill(NONCE_LEN), for we want to
			* return date from buffer, not return decrypted buffer,
			* which is empty by now. */
			pack_is_encrypted = 1;
			git_decryptor_init_or_die(&cryptor_r, hdr_version, in);
			cryptor_r.byte_counter = sizeof(struct pack_header_with_nonce);

			use(NONCE_LEN);
		} else {
			pack_is_encrypted = 1;
			git_decryptor_init_or_die(&cryptor_r, hdr_version,
						  NULL);
			cryptor_r.byte_counter = sizeof(struct pack_header);
		}

		/* Decrypt buffer follows the header. */
		if (len)
			cryptor_r.decrypt(&cryptor_r,
					  buffer + offset,
					  decrypt_buffer + offset,
					  len,
					  len);
	}
}

/*
 * Called only from check_object() after it verified this object
 * is Ok.
 */
static void write_cached_object(struct object *obj, struct obj_buffer *obj_buf)
{
	struct object_id oid;

	if (write_object_file(obj_buf->buffer, obj_buf->size,
			      obj->type, &oid) < 0)
		die("failed to write object %s", oid_to_hex(&obj->oid));
	obj->flags |= FLAG_WRITTEN;
}

/*
 * At the very end of the processing, write_rest() scans the objects
 * that have reachability requirements and calls this function.
 * Verify its reachability and validity recursively and write it out.
 */
static int check_object(struct object *obj, enum object_type type,
			void *data, struct fsck_options *options)
{
	struct obj_buffer *obj_buf;

	if (!obj)
		return 1;

	if (obj->flags & FLAG_WRITTEN)
		return 0;

	if (type != OBJ_ANY && obj->type != type)
		die("object type mismatch");

	if (!(obj->flags & FLAG_OPEN)) {
		unsigned long size;
		int type = oid_object_info(the_repository, &obj->oid, &size);
		if (type != obj->type || type <= 0)
			die("object of unexpected type");
		obj->flags |= FLAG_WRITTEN;
		return 0;
	}

	obj_buf = lookup_object_buffer(obj);
	if (!obj_buf)
		die("Whoops! Cannot find object '%s'", oid_to_hex(&obj->oid));
	if (fsck_object(obj, obj_buf->buffer, obj_buf->size, &fsck_options))
		die("fsck error in packed object");
	fsck_options.walk = check_object;
	if (fsck_walk(obj, NULL, &fsck_options))
		die("Error on reachable objects of %s", oid_to_hex(&obj->oid));
	write_cached_object(obj, obj_buf);
	return 0;
}

static void write_rest(void)
{
	unsigned i;
	for (i = 0; i < nr_objects; i++) {
		if (obj_list[i].obj)
			check_object(obj_list[i].obj, OBJ_ANY, NULL, NULL);
	}
}

static void added_object(unsigned nr, enum object_type type,
			 void *data, unsigned long size);

/*
 * Write out nr-th object from the list, now we know the contents
 * of it.  Under --strict, this buffers structured objects in-core,
 * to be checked at the end.
 */
static void write_object(unsigned nr, enum object_type type,
			 void *buf, unsigned long size)
{
	if (!strict) {
		if (write_object_file(buf, size, type,
				      &obj_list[nr].oid) < 0)
			die("failed to write object");
		added_object(nr, type, buf, size);
		free(buf);
		obj_list[nr].obj = NULL;
	} else if (type == OBJ_BLOB) {
		struct blob *blob;
		if (write_object_file(buf, size, type,
				      &obj_list[nr].oid) < 0)
			die("failed to write object");
		added_object(nr, type, buf, size);
		free(buf);

		blob = lookup_blob(the_repository, &obj_list[nr].oid);
		if (blob)
			blob->object.flags |= FLAG_WRITTEN;
		else
			die("invalid blob object");
		obj_list[nr].obj = NULL;
	} else {
		struct object *obj;
		int eaten;
		hash_object_file(the_hash_algo, buf, size, type,
				 &obj_list[nr].oid);
		added_object(nr, type, buf, size);
		obj = parse_object_buffer(the_repository, &obj_list[nr].oid,
					  type, size, buf,
					  &eaten);
		if (!obj)
			die("invalid %s", type_name(type));
		add_object_buffer(obj, buf, size);
		obj->flags |= FLAG_OPEN;
		obj_list[nr].obj = obj;
	}
}

static void resolve_delta(unsigned nr, enum object_type type,
			  void *base, unsigned long base_size,
			  void *delta, unsigned long delta_size)
{
	void *result;
	unsigned long result_size;

	result = patch_delta(base, base_size,
			     delta, delta_size,
			     &result_size);
	if (!result)
		die("failed to apply delta");
	free(delta);
	write_object(nr, type, result, result_size);
}

/*
 * We now know the contents of an object (which is nr-th in the pack);
 * resolve all the deltified objects that are based on it.
 */
static void added_object(unsigned nr, enum object_type type,
			 void *data, unsigned long size)
{
	struct delta_info **p = &delta_list;
	struct delta_info *info;

	while ((info = *p) != NULL) {
		if (oideq(&info->base_oid, &obj_list[nr].oid) ||
		    info->base_offset == obj_list[nr].offset) {
			*p = info->next;
			p = &delta_list;
			resolve_delta(info->nr, type, data, size,
				      info->delta, info->size);
			free(info);
			continue;
		}
		p = &info->next;
	}
}

struct input_zstream_data {
	git_zstream *zstream;
	unsigned char buf[8192];
	int status;
};

static const void *feed_input_zstream(struct input_stream *in_stream,
				      unsigned long *readlen)
{
	struct input_zstream_data *data = in_stream->data;
	git_zstream *zstream = data->zstream;
	void *in = fill(1);

	if (data->status != Z_OK) {
		*readlen = 0;
		return NULL;
	}

	zstream->next_out = data->buf;
	zstream->avail_out = sizeof(data->buf);
	zstream->next_in = in;
	zstream->avail_in = len;

	data->status = git_inflate(zstream, 0);

	in_stream->is_finished = data->status != Z_OK;
	use(len - zstream->avail_in);
	*readlen = sizeof(data->buf) - zstream->avail_out;

	return data->buf;
}

static void write_stream_blob(unsigned nr, unsigned long size)
{
	git_zstream zstream;
	struct input_zstream_data data;
	struct input_stream in_stream = {
		.read = feed_input_zstream,
		.data = &data,
	};

	memset(&zstream, 0, sizeof(zstream));
	memset(&data, 0, sizeof(data));
	data.zstream = &zstream;
	git_inflate_init(&zstream);

	if (write_object_file_flags(&in_stream, size,
				    type_name(OBJ_BLOB),
				    &obj_list[nr].oid,
				    HASH_STREAM))
		die(_("failed to write object in stream"));

	if (zstream.total_out != size)
		die(_("inflate input data is %ld != %"PRIuMAX), zstream.total_out,
		    (uintmax_t)size);
	if (data.status != Z_STREAM_END)
		die(_("inflate returned (%d)"), data.status);
	git_inflate_end(&zstream);

	if (strict) {
		struct blob *blob = lookup_blob(the_repository, &obj_list[nr].oid);
		if (blob)
			blob->object.flags |= FLAG_WRITTEN;
		else
			die(_("invalid blob object from stream"));
	}
	obj_list[nr].obj = NULL;
}

static void unpack_non_delta_entry(enum object_type type, unsigned long size,
				   unsigned nr)
{
	void *buf;

	/* Write large blob in stream without allocating full buffer. */
	if (!dry_run && type == OBJ_BLOB && size > big_file_threshold) {
		write_stream_blob(nr, size);
		return;
	}

	buf = get_data(size, dry_run);
	if (!dry_run && buf)
		write_object(nr, type, buf, size);
	else
		free(buf);
}

static int resolve_against_held(unsigned nr, const struct object_id *base,
				void *delta_data, unsigned long delta_size)
{
	struct object *obj;
	struct obj_buffer *obj_buffer;
	obj = lookup_object(the_repository, base);
	if (!obj)
		return 0;
	obj_buffer = lookup_object_buffer(obj);
	if (!obj_buffer)
		return 0;
	resolve_delta(nr, obj->type, obj_buffer->buffer,
		      obj_buffer->size, delta_data, delta_size);
	return 1;
}

static void unpack_delta_entry(enum object_type type, unsigned long delta_size,
			       unsigned nr)
{
	void *delta_data, *base;
	unsigned long base_size;
	struct object_id base_oid;

	if (type == OBJ_REF_DELTA) {
		oidread(&base_oid, fill(the_hash_algo->rawsz));
		use(the_hash_algo->rawsz);
		delta_data = get_data(delta_size, dry_run);
		if (dry_run || !delta_data) {
			free(delta_data);
			return;
		}
		if (has_object_file(&base_oid))
			; /* Ok we have this one */
		else if (resolve_against_held(nr, &base_oid,
					      delta_data, delta_size))
			return; /* we are done */
		else {
			/* cannot resolve yet --- queue it */
			oidclr(&obj_list[nr].oid);
			add_delta_to_list(nr, &base_oid, 0, delta_data, delta_size);
			return;
		}
	} else {
		unsigned base_found = 0;
		unsigned char *pack, c;
		off_t base_offset;
		unsigned lo, mid, hi;

		pack = fill(1);
		c = *pack;
		use(1);
		base_offset = c & 127;
		while (c & 128) {
			base_offset += 1;
			if (!base_offset || MSB(base_offset, 7))
				die("offset value overflow for delta base object");
			pack = fill(1);
			c = *pack;
			use(1);
			base_offset = (base_offset << 7) + (c & 127);
		}
		base_offset = obj_list[nr].offset - base_offset;
		if (base_offset <= 0 || base_offset >= obj_list[nr].offset)
			die("offset value out of bound for delta base object");

		delta_data = get_data(delta_size, dry_run);
		if (dry_run || !delta_data) {
			free(delta_data);
			return;
		}
		lo = 0;
		hi = nr;
		while (lo < hi) {
			mid = lo + (hi - lo) / 2;
			if (base_offset < obj_list[mid].offset) {
				hi = mid;
			} else if (base_offset > obj_list[mid].offset) {
				lo = mid + 1;
			} else {
				oidcpy(&base_oid, &obj_list[mid].oid);
				base_found = !is_null_oid(&base_oid);
				break;
			}
		}
		if (!base_found) {
			/*
			 * The delta base object is itself a delta that
			 * has not been resolved yet.
			 */
			oidclr(&obj_list[nr].oid);
			add_delta_to_list(nr, null_oid(), base_offset,
					  delta_data, delta_size);
			return;
		}
	}

	if (resolve_against_held(nr, &base_oid, delta_data, delta_size))
		return;

	base = read_object_file(&base_oid, &type, &base_size);
	if (!base) {
		error("failed to read delta-pack base object %s",
		      oid_to_hex(&base_oid));
		if (!recover)
			exit(1);
		has_errors = 1;
		return;
	}
	resolve_delta(nr, type, base, base_size, delta_data, delta_size);
	free(base);
}

static void check_input_object(const char *type_name, unsigned long size)
{
	if (max_input_object_size && size > max_input_object_size)
		die(_("%s exceeds maximum allowed size %ld over %"PRIuMAX),
		    type_name, size, (uintmax_t)max_input_object_size);
}

static void check_input_blob(unsigned long size)
{
	/* use blob size limit for delta */
	if (max_input_blob_size) {
		if (size > max_input_blob_size)
			die(_("object exceeds maximum allowed size %ld over %"PRIuMAX),
			    size, (uintmax_t)max_input_blob_size);
	} else {
		check_input_object("object", size);
	}
}

static void unpack_one(unsigned nr)
{
	unsigned shift;
	unsigned char *pack;
	unsigned long size, c;
	enum object_type type;

	obj_list[nr].offset = consumed_bytes;

	pack = fill(1);
	c = *pack;
	use(1);
	type = (c >> 4) & 7;
	size = (c & 15);
	shift = 4;
	while (c & 0x80) {
		pack = fill(1);
		c = *pack;
		use(1);
		size += (c & 0x7f) << shift;
		shift += 7;
	}

	switch (type) {
	case OBJ_BLOB:
		check_input_blob(size);
		unpack_non_delta_entry(type, size, nr);
		return;
	case OBJ_COMMIT:
	case OBJ_TREE:
	case OBJ_TAG:
		check_input_object(type_name(type), size);
		unpack_non_delta_entry(type, size, nr);
		return;
	case OBJ_REF_DELTA:
	case OBJ_OFS_DELTA:
		/* use blob size limit for delta */
		check_input_blob(size);
		unpack_delta_entry(type, size, nr);
		return;
	default:
		error("bad object type %d", type);
		has_errors = 1;
		if (recover)
			return;
		exit(1);
	}
}

static void unpack_all(void)
{
	int i;

	fill_header();

	if (!quiet)
		progress = start_progress(_("Unpacking objects"), nr_objects);
	CALLOC_ARRAY(obj_list, nr_objects);
	for (i = 0; i < nr_objects; i++) {
		unpack_one(i);
		display_progress(progress, i + 1);
	}
	stop_progress(&progress);

	if (delta_list)
		die("unresolved deltas left after unpacking");
}

int cmd_unpack_objects(int argc, const char **argv, const char *prefix)
{
	int i;
	struct object_id oid;

	read_replace_refs = 0;

	git_config(git_default_config, NULL);

	quiet = !isatty(2);

	for (i = 1 ; i < argc; i++) {
		const char *arg = argv[i];

		if (*arg == '-') {
			if (!strcmp(arg, "-n")) {
				dry_run = 1;
				continue;
			}
			if (!strcmp(arg, "-q")) {
				quiet = 1;
				continue;
			}
			if (!strcmp(arg, "-r")) {
				recover = 1;
				continue;
			}
			if (!strcmp(arg, "--strict")) {
				strict = 1;
				continue;
			}
			if (skip_prefix(arg, "--strict=", &arg)) {
				strict = 1;
				fsck_set_msg_types(&fsck_options, arg);
				continue;
			}
			if (starts_with(arg, "--pack_header=")) {
				struct pack_header *hdr;
				char *c;

				hdr = (struct pack_header *)buffer;
				hdr->hdr_signature = htonl(PACK_SIGNATURE);
				hdr->hdr_version = htonl(strtoul(arg + 14, &c, 10));
				if (*c != ',')
					die("bad %s", arg);
				hdr->hdr_entries = htonl(strtoul(c + 1, &c, 10));
				if (*c)
					die("bad %s", arg);
				len = sizeof(*hdr);
				continue;
			}
			if (skip_prefix(arg, "--max-input-size=", &arg)) {
				max_input_size = strtoumax(arg, NULL, 10);
				continue;
			}
			if (skip_prefix(arg, "--max-input-blob-size=", &arg)) {
				max_input_blob_size = strtoumax(arg, NULL, 10);
				continue;
			}
			if (skip_prefix(arg, "--max-input-object-size=", &arg)) {
				max_input_object_size = strtoumax(arg, NULL, 10);
				continue;
			}
			usage(unpack_usage);
		}

		/* We don't take any non-flag arguments now.. Maybe some day */
		usage(unpack_usage);
	}
	the_hash_algo->init_fn(&ctx);
	unpack_all();
	the_hash_algo->update_fn(&ctx, buffer, offset);
	the_hash_algo->final_oid_fn(&oid, &ctx);
	if (strict) {
		write_rest();
		if (fsck_finish(&fsck_options))
			die(_("fsck error in pack objects"));
	}
	fill(the_hash_algo->rawsz);
	/* The checksum at the end of packfile is unencrypted, but
	 * after call fill, the return decrypt_buffer is mangled.
	 */
	if (!hasheq(buffer + offset, oid.hash))
		die("final sha1 did not match");
	use(the_hash_algo->rawsz);

	/* Write the last part of the buffer to stdout */
	while (len) {
		int ret = xwrite(1, buffer + offset, len);
		if (ret <= 0)
			break;
		len -= ret;
		offset += ret;
	}

	/* All done */
	return has_errors;
}
