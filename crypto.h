#ifndef CRYPTO_H
#define CRYPTO_H

#ifdef NO_OPENSSL
#error re-configure using "--with-openssl=path/of/openssl" to build git-crypto
#endif

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
 * The most significant bit indicates encryption status.
 *
 * 0xxx xxxx : no encryption.
 *
 * 10xx xxxx : encrypt algorithm 0 - 63 (0xx xxxx),
 *             which has an extend header (24 bytes total), the
 *             additional 12 bytes used as nonce for cryptology.
 *
 * 110x xxxx : encrypt algorithm 64 - 95 (10x xxxx),
 *             which has a normal fixed 12-byte header, and
 *             the 6/7th bytes as salt.
 *
 * 1110 xxxx xxxx xxxx xxxx xxxx : encrypt algorithm 96 - 1048671,
 *             which is reserved for future use.
 */

/* Algorithm */
enum agit_crypto_algo {
	/* Algorithm 1 - 63 (0xx xxxx), which has an additional
	 * 12 bytes used as nonce for cryption */
	GIT_CRYPTO_ALGORITHM_BENCHMARK = 1, /* test only, do not use in
					       production */
	GIT_CRYPTO_ALGORITHM_AES = 2,

	/* Algorithm 64 - 95 (10x xxxx), which used normal header,
	 * and the 6/7th bytes are used as 2-byte salt. */
	GIT_CRYPTO_ALGORITHM_EASY_BENCHMARK = 64, /* test only, do not use in
						     production */
	GIT_CRYPTO_ALGORITHM_EASY_AES = 65
};
#define GIT_CRYPTO_ALGORITHM_DEFAULT GIT_CRYPTO_ALGORITHM_AES

/*
 * The 6th and 7th bytes are preserved for later use.
 *
 * The 8th byte of the header is version for packfile, or reserved
 * for loose object.
 */

extern const char *agit_crypto_secret;
extern const char *agit_crypto_nonce;
/* enable git crypto will make sha-file or packfile encrypted */
extern int agit_crypto_enabled;
extern int agit_crypto_default_algorithm;

typedef struct git_cryptor {
	enum agit_crypto_algo algorithm;
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

int crypto_pack_has_longer_nonce_for_version(uint32_t net_version);

int crypto_pack_has_longer_nonce_for_algo(int algo);

/* init git encryptor or die password not given */
void git_encryptor_init_or_die(git_cryptor *cryptor, int is_pack);

#define git_encryptor_init_for_loose_object(v) git_encryptor_init_or_die(v, 0)
#define git_encryptor_init_for_packfile(v) git_encryptor_init_or_die(v, 1)

/* init git decryptor or die password not given */
void git_decryptor_init_or_die(git_cryptor *, uint32_t hdr_version,
			       unsigned char *nonce);

/* get pack version */
uint32_t git_encryptor_get_host_pack_version(git_cryptor *,
					     unsigned char *nonce);

/* get cryptor header */
unsigned char *git_encryptor_get_net_object_header(git_cryptor *,
						   unsigned char *header);

#endif
