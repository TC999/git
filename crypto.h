#ifndef CRYPTO_H
#define CRYPTO_H

#include "cache.h"

/*
 * The first 4 bytes of a header is signature.
 * Signature for encrypted loose object is "ENC\0".
 */
static const unsigned char git_crypto_lo_signature[4] = {
	'E', 'N', 'C', '\0'
};
#define GIT_CRYPTO_LO_HAS_SIGNATURE(s)	memcmp(s, git_crypto_lo_signature, 4)
#define GIT_CRYPTO_LO_HEADER_SIZE	8

/*
 * The 5th byte of the header defines block size and algorithm.
 * All the 8 bits are:
 *
 *   1  : Indicate the pack or loose object is encrypted.
 *   2-4: Block size.
 *   5-8: Algorithm.
 */
#define GIT_CRYPTO_PACK_IS_ENCRYPT(v)	(ntohl(v) >> 31)

/* Block size: 0-15 */
#define GIT_CRYPTO_BLOCK_SIZE_32	0
#define GIT_CRYPTO_BLOCK_SIZE_1k	1
#define GIT_CRYPTO_BLOCK_SIZE_32k	2
#define GIT_CRYPTO_BLOCK_SIZE_DEFAULT	2

/* Algorithm: 0-15 */
#define GIT_CRYPTO_ALGORITHM_SIMPLE	1
#define GIT_CRYPTO_ALGORITHM_DEFAULT	1

/*
 * The 6th and 7th bytes of the header are used to store the salt for
 * crypto algorithm, which is in network byte order.
 *
 * The 8th byte of the header is version for packfile, or is reserved
 * for loose object.
 */

/* decrypt buffer zlib compress too small input may return a bigger output */
#define GIT_CRYPTO_DECRYPT_BUFFER_SIZE 256

extern const char *agit_crypto_secret;
extern const char *agit_crypto_salt;
/* enable git crypto will make sha-file or packfile encrypted */
extern int agit_crypto_enabled;
extern int agit_pack_encrypted;

typedef struct git_cryptor {
	uint8_t algorithm;
	uint16_t salt;
	size_t byte_counter;

	uint32_t block_size;
	uint32_t block_shift;

	/* gen secret sequence  */
	int (*gen_sec_sequence)(struct git_cryptor *, unsigned char *seq,
				uint32_t len);

	/* do git encrypt with given input and write to out */
	void (*encrypt)(struct git_cryptor *, const unsigned char *in,
			unsigned char *out, size_t avail_in);

	/* do git decrypt with given input and write to out */
	void (*decrypt)(struct git_cryptor *, const unsigned char *in,
			unsigned char *out, size_t avail_in, size_t avail_out);
} git_cryptor;

/* init git encryptor or die password not given */
void git_encryptor_init_or_die(git_cryptor *);

/* init git decryptor or die password not given */
void git_decryptor_init_or_die(git_cryptor *, uint32_t hdr_version);

/* get pack version */
uint32_t git_encryptor_get_host_pack_version(git_cryptor *);

/* get cryptor header */
unsigned char *git_encryptor_get_net_object_header(git_cryptor *,
						   unsigned char *header);

#endif
