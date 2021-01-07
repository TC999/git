/*
 * csum-file.c
 *
 * Copyright (C) 2005 Linus Torvalds
 *
 * Simple file write infrastructure for writing SHA1-summed
 * files. Useful when you write a file that you want to be
 * able to verify hasn't been messed with afterwards.
 */
#include "cache.h"
#include "crypto.h"
#include "progress.h"
#include "csum-file.h"

static void verify_buffer_or_die(struct hashfile *f,
				 const void *buf,
				 unsigned int count)
{
	ssize_t ret = read_in_full(f->check_fd, f->check_buffer, count);

	if (ret < 0)
		die_errno("%s: sha1 file read error", f->name);
	if (ret != count)
		die("%s: sha1 file truncated", f->name);
	if (memcmp(buf, f->check_buffer, count))
		die("sha1 file '%s' validation error", f->name);
}

static void flush(struct hashfile *f, const void *buf, unsigned int count)
{
	if (0 <= f->check_fd && count)
		verify_buffer_or_die(f, buf, count);

	if (write_in_full(f->fd, buf, count) < 0) {
		if (errno == ENOSPC)
			die("sha1 file '%s' write error. Out of diskspace", f->name);
		die_errno("sha1 file '%s' write error", f->name);
	}

	f->total += count;
	display_throughput(f->tp, f->total);
}

void hashflush(struct hashfile *f)
{
	unsigned offset = f->offset;

	if (offset) {
		the_hash_algo->update_fn(&f->ctx, f->buffer, offset);
		flush(f, f->buffer, offset);
		f->offset = 0;
	}
}

static void free_hashfile(struct hashfile *f)
{
	free(f->buffer);
	free(f->check_buffer);
	free(f);
}

int finalize_hashfile(struct hashfile *f, unsigned char *result,
		      enum fsync_component component, unsigned int flags)
{
	int fd;

	hashflush(f);
	the_hash_algo->final_fn(f->buffer, &f->ctx);
	if (result)
		hashcpy(result, f->buffer);
	if (flags & CSUM_HASH_IN_STREAM)
		flush(f, f->buffer, the_hash_algo->rawsz);
	if (flags & CSUM_FSYNC)
		fsync_component_or_die(component, f->fd, f->name);
	if (flags & CSUM_CLOSE) {
		if (close(f->fd))
			die_errno("%s: sha1 file error on close", f->name);
		fd = 0;
	} else
		fd = f->fd;
	if (0 <= f->check_fd) {
		char discard;
		int cnt = read_in_full(f->check_fd, &discard, 1);
		if (cnt < 0)
			die_errno("%s: error when reading the tail of sha1 file",
				  f->name);
		if (cnt)
			die("%s: sha1 file has trailing garbage", f->name);
		if (close(f->check_fd))
			die_errno("%s: sha1 file error on close", f->name);
	}
	if (!(flags & CSUM_CRYPTOR_NO_FREE))
		free(f->cryptor);
	free_hashfile(f);
	return fd;
}

static void do_hashwrite(struct hashfile *f, const void *buf, unsigned int count, int do_encrypt)
{
	unsigned int total = count;

	if (do_encrypt && f->cryptor)
		f->cryptor->byte_counter = f->encrypt_offset;

	while (count) {
		unsigned offset = f->offset;
		unsigned left = f->buffer_len - f->offset;
		unsigned nr = count > left ? left : count;
		const void *data;

		/* iff offset == 0, and left = nr = sizeof(f->buffer) */
		if (nr == f->buffer_len) {
			if (do_encrypt && f->cryptor) {
				/* 'buf' maybe a mmap for reused packfile, so
				 * copy * 'buf' to 'f->buffer' for encrypt.
				 */
				f->cryptor->encrypt(f->cryptor, buf, f->buffer, nr);
				data = f->buffer;
			} else {
				/* process full buffer directly without copy */
				data = buf;
			}
		} else {
			if (do_encrypt && f->cryptor) {
				f->cryptor->encrypt(f->cryptor, buf, f->buffer + offset, nr);
			} else {
				memcpy(f->buffer + offset, buf, nr);
			}
			data = f->buffer;
		}

		/* Do crc on encrypted data. */
		if (f->do_crc)
			f->crc32 = crc32(f->crc32, (unsigned char *)data + offset, nr);

		count -= nr;
		offset += nr;
		buf = (char *)buf + nr;
		left -= nr;
		if (!left) {
			/* Update checksum using encrypted data. */
			the_hash_algo->update_fn(&f->ctx, data, offset);
			flush(f, data, offset);
			offset = 0;
		}
		f->offset = offset;
	}
	/* No matter do_encrypt or not, set encrypt_offset. */
	f->encrypt_offset += total;
}

void hashwrite(struct hashfile *f, const void *buf, unsigned int count)
{
	do_hashwrite(f, buf, count, 0);
}

void hashwrite_try_encrypt(struct hashfile *f, const void *buf, unsigned int count)
{
	do_hashwrite(f, buf, count, 1);
}

struct hashfile *hashfd_check(const char *name)
{
	int sink, check;
	struct hashfile *f;

	sink = xopen("/dev/null", O_WRONLY);
	check = xopen(name, O_RDONLY);
	f = hashfd(sink, name);
	f->check_fd = check;
	f->check_buffer = xmalloc(f->buffer_len);

	return f;
}

static struct hashfile *hashfd_internal(int fd, const char *name,
					struct progress *tp,
					size_t buffer_len)
{
	struct hashfile *f = xmalloc(sizeof(*f));
	f->fd = fd;
	f->check_fd = -1;
	f->offset = 0;
	f->total = 0;
	f->tp = tp;
	f->name = name;
	f->do_crc = 0;
	f->encrypt_offset = 0;
	f->cryptor = NULL;
	the_hash_algo->init_fn(&f->ctx);

	f->buffer_len = buffer_len;
	f->buffer = xmalloc(buffer_len);
	f->check_buffer = NULL;

	return f;
}

struct hashfile *hashfd(int fd, const char *name)
{
	/*
	 * Since we are not going to use a progress meter to
	 * measure the rate of data passing through this hashfile,
	 * use a larger buffer size to reduce fsync() calls.
	 */
	return hashfd_internal(fd, name, NULL, 128 * 1024);
}

struct hashfile *hashfd_throughput(int fd, const char *name, struct progress *tp)
{
	/*
	 * Since we are expecting to report progress of the
	 * write into this hashfile, use a smaller buffer
	 * size so the progress indicators arrive at a more
	 * frequent rate.
	 */
	return hashfd_internal(fd, name, tp, 8 * 1024);
}

void hashfile_checkpoint(struct hashfile *f, struct hashfile_checkpoint *checkpoint)
{
	hashflush(f);
	checkpoint->offset = f->total;
	the_hash_algo->clone_fn(&checkpoint->ctx, &f->ctx);
}

int hashfile_truncate(struct hashfile *f, struct hashfile_checkpoint *checkpoint)
{
	off_t offset = checkpoint->offset;

	if (ftruncate(f->fd, offset) ||
	    lseek(f->fd, offset, SEEK_SET) != offset)
		return -1;
	f->total = offset;
	f->ctx = checkpoint->ctx;
	f->offset = 0; /* hashflush() was called in checkpoint */
	return 0;
}

void crc32_begin(struct hashfile *f)
{
	f->crc32 = crc32(0, NULL, 0);
	f->do_crc = 1;
}

uint32_t crc32_end(struct hashfile *f)
{
	f->do_crc = 0;
	return f->crc32;
}

int hashfile_checksum_valid(const unsigned char *data, size_t total_len)
{
	unsigned char got[GIT_MAX_RAWSZ];
	git_hash_ctx ctx;
	size_t data_len = total_len - the_hash_algo->rawsz;

	if (total_len < the_hash_algo->rawsz)
		return 0; /* say "too short"? */

	the_hash_algo->init_fn(&ctx);
	the_hash_algo->update_fn(&ctx, data, data_len);
	the_hash_algo->final_fn(got, &ctx);

	return hasheq(got, data + data_len);
}
