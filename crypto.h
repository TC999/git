#ifndef CRYPTO_H
#define CRYPTO_H

#include <openssl/evp.h>

/*
 * The first bit of pack version (network byte order)
 * indicates that the packfile is encrypted.
 */
#define git_crypto_pack_is_encrypt(v)	(ntohl(v) >> 31)

#define NONCE_LEN 12
/*
 * The first 4 bytes of a header is signature.
 * Signature for encrypted loose object is "ENC\0".
 */
#define GIT_CRYPTO_LO_HEADER_SIZE	20
static const unsigned char git_crypto_lo_signature[4] = {
	'E', 'N', 'C', '\0'
};
#define git_crypto_lo_has_signature(s)	(!memcmp(s, git_crypto_lo_signature, 4))

/*
 * The 5th byte of the header defines crypto algorithm.
 * All the 8 bits are:
 *
 *   1  : Indicate the pack or loose object is encrypted.
 *   2-8: Algorithm.
 */

/* Algorithm: 0-15 */
enum agit_crypto_algo {
	GIT_CRYPTO_ALGORITHM_HASH = 1,
	GIT_CRYPTO_ALGORITHM_AES = 2
};
#define GIT_CRYPTO_ALGORITHM_DEFAULT GIT_CRYPTO_ALGORITHM_AES

/*
 * The 6th and 7th bytes are preserved for later use.
 *
 * The 8th byte of the header is version for packfile, or reserved
 * for loose object.
 */

/* Threshold for size of loose object, do not encrypt for loose object larger
 * than this size. */
#define GIT_CRYPTO_ENCRYPT_LO_MAX_SIZE 10 * 1024 * 1024 /* 10MB */

extern const char *agit_crypto_secret;
extern const char *agit_crypto_nonce;
/* enable git crypto will make sha-file or packfile encrypted */
extern int agit_crypto_enabled;

typedef struct git_cryptor {
	uint8_t algorithm;
	unsigned char nonce[NONCE_LEN + 4];
	size_t byte_counter;
	/* Must allocate secret_sequence longer enough for HASH function.
	 * SHA256 hash needs 32 bytes.
	 */
	unsigned char secret_sequence[32];
	uint32_t pos_n_last;
	EVP_CIPHER_CTX *ctx;

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
void git_decryptor_init_or_die(git_cryptor *, uint32_t hdr_version,
			       unsigned char *nonce, int len);

/* get pack version */
uint32_t git_encryptor_get_host_pack_version(git_cryptor *);

/* get cryptor header */
unsigned char *git_encryptor_get_net_object_header(git_cryptor *,
						   unsigned char *header);

#endif
