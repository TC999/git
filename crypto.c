/*
 * crypt.c - crypto wrapper
 *
 * Copyright (C) 2020 Chi Tian <hanxin.hx@alibaba-inc.com>
 */
#include "git-compat-util.h"
#include "crypto.h"
#include "pack.h"

const char *agit_crypto_secret;
const char *agit_crypto_nonce;
int agit_crypto_enabled;
int agit_crypto_default_algorithm;

static int srand_once;

static inline enum agit_crypto_algo
crypto_get_algo_from_net_version(uint32_t net_version)
{
	return (ntohl(net_version) >> 24) & 0x7f;
}

int crypto_pack_has_longer_nonce_for_algo(int algo)
{
	/* Encrypt algorithm 64 - 95 (10x xxxx) has a 2-bytes nonce/slat */
	if (algo >= 64 && algo <= 95)
		return 0;
	/* Encrypt algorithm 1 - 63 (0xx xxxx) has a 12-bytes nonce */
	if (algo < 64 && algo > 0)
		return 1;
	die("unsupported algo: %d", algo);
}

int crypto_pack_has_longer_nonce_for_version(uint32_t net_version)
{
	return crypto_pack_has_longer_nonce_for_algo(
		crypto_get_algo_from_net_version(net_version));
}

static int crypto_packfile_nonce_length(int algo)
{
	if (crypto_pack_has_longer_nonce_for_algo(algo))
		return NONCE_LEN;
	else
		return 2; /* salt in the 6/7th bytes of header */
}

/*
 * The 1st bit is always 1, which indicates pack or loose object is encrypted.
 */
static enum agit_crypto_algo crypto_new_algorithim(enum agit_crypto_algo algo)
{
	switch (algo) {
	default:
		die("bad algorithm: %x\n", algo);
		break;
	case GIT_CRYPTO_ALGORITHM_BENCHMARK:
		/* fallthrough */
	case GIT_CRYPTO_ALGORITHM_AES:
		/* fallthrough */
	case GIT_CRYPTO_ALGORITHM_EASY_BENCHMARK:
		/* fallthrough */
	case GIT_CRYPTO_ALGORITHM_EASY_AES:
		break;
	}

	return algo;
}

/*
 * Setup secret sequence for each block, and returns length of
 * sequence generated.
 */
static int gen_sec_sequence_benchmark(git_cryptor *cryptor, unsigned char *seq,
				      uint32_t len)
{
	/* pos = cryptor->byte_counter / 16 */
	uint32_t pos_n = htonl(cryptor->byte_counter >> 4);
	int ret = 16;
	/* mix test writes 16 bytes */
	assert(len >= ret);

	if (pos_n != 0 && pos_n == cryptor->pos_n_last)
		return ret;
	else
		cryptor->pos_n_last = pos_n;

	memcpy(cryptor->nonce + NONCE_LEN, &pos_n, sizeof(uint32_t));
	/* do nothing for seq */
	return ret;
}

/*
 * Setup secret sequence for each block, and returns length of
 * sequence generated.
 */
static int gen_sec_sequence_aes(git_cryptor *cryptor, unsigned char *seq,
				 uint32_t len)
{
	/* pos = cryptor->byte_counter / 16 */
	uint32_t pos_n = htonl(cryptor->byte_counter >> 4);
	int ret = 16, ciphertext_len;
	/* aes writes 16 bytes */
	assert(len >= ret);

	if (pos_n != 0 && pos_n == cryptor->pos_n_last)
		return ret;
	else
		cryptor->pos_n_last = pos_n;

	memcpy(cryptor->nonce + NONCE_LEN, &pos_n, sizeof(uint32_t));

	if (1 != EVP_EncryptUpdate(cryptor->ctx, seq, &ciphertext_len,
				   (const unsigned char *)cryptor->nonce, ret))
		die("aes encrypt nonce failed");
	assert(ciphertext_len == ret);
	return ret;
}

static void git_decrypt(git_cryptor *cryptor, const unsigned char *in,
			unsigned char *out, size_t avail_in, size_t avail_out)
{
	int sec_seq_init = 0, sec_seq_len, i, pos, post_avail;
	size_t avail = avail_in < avail_out ? avail_in : avail_out;

	while (avail) {
		if (!sec_seq_init) {
			sec_seq_len = cryptor->gen_sec_sequence(
				cryptor, cryptor->secret_sequence,
				sizeof(cryptor->secret_sequence));
			pos = cryptor->byte_counter & (sec_seq_len - 1);
			sec_seq_init = 1;
		} else if (pos == 0)
			sec_seq_len = cryptor->gen_sec_sequence(
				cryptor, cryptor->secret_sequence,
				sizeof(cryptor->secret_sequence));

		post_avail = (sec_seq_len - pos) < avail ? sec_seq_len - pos :
							   avail;

		for (i = 0; i < post_avail; i++) {
			/* encrypt one byte */
			*out++ = *in++ ^ cryptor->secret_sequence[
				pos++ & (sec_seq_len - 1)];
		}

		pos = 0;
		cryptor->byte_counter += i;
		avail -= i;
	}
}

static void git_encrypt(git_cryptor *cryptor, const unsigned char *in,
			unsigned char *out, size_t avail_in)
{
	cryptor->decrypt(cryptor, in, out, avail_in, avail_in);
}

static int git_crypto_get_secret(unsigned char **secret)
{
	const char *input_secret = agit_crypto_secret;
	int input_len;
	int base64_decode = -1;
	int len;

	if (!input_secret)
		die("crypto secret is unset");

	if (!strncasecmp(input_secret, "{base64}", 8)) {
		input_secret += 8;
		base64_decode = 1;
	} else if (!strncasecmp(input_secret, "{plain}", 7)) {
		input_secret += 7;
		base64_decode = 0;
	}
	input_len = strlen(input_secret);
	if (input_len < 8)
		die("secret token is too short");

	/* Password padding: make sure have 16 or more characters,
	 * because random data may try to fill 16 secret characters. */
	len = input_len > 16 ? input_len: 16;
	*secret = xmalloc(len);
	memset(*secret, 0, len);
	if (!base64_decode) {
		memcpy(*secret, input_secret, input_len);
	} else {
		len = EVP_DecodeBlock(
			*secret, (const unsigned char *)input_secret,
			input_len);
		if (len <= 0) {
			if (base64_decode == 1)
				die("decode secret failed");
			len = input_len;
			memcpy(*secret, input_secret, input_len);
		}
		/* Random data will fill to pad 16 characters if len < 16. */
		if (len < 16) {
			len = 16;
		}
	}
	return len;
}

/* set up crypto method */
static void git_crypto_setup(git_cryptor *cryptor)
{
	unsigned char *secret = NULL;
	int secret_len;

	secret_len = git_crypto_get_secret(&secret);

	cryptor->encrypt = &git_encrypt;
	cryptor->decrypt = &git_decrypt;

	switch (cryptor->algorithm) {
	case GIT_CRYPTO_ALGORITHM_BENCHMARK:
	case GIT_CRYPTO_ALGORITHM_EASY_BENCHMARK:
		{
		git_SHA256_CTX ctx;
		git_SHA256_Init(&ctx);
		git_SHA256_Update(&ctx, secret, secret_len);
		git_SHA256_Final(cryptor->secret_sequence, &ctx);
		cryptor->gen_sec_sequence = &gen_sec_sequence_benchmark;
		}
		break;
	case GIT_CRYPTO_ALGORITHM_AES:
	case GIT_CRYPTO_ALGORITHM_EASY_AES:
		{
		if (!(cryptor->ctx = EVP_CIPHER_CTX_new()))
			die("new aes ctx failed");

		if (secret_len >= 32) {
			if (!(EVP_EncryptInit_ex(cryptor->ctx,
						 EVP_aes_256_ecb(), NULL,
						 secret, NULL)))
				die("setup aes256 encrypt key failed");
		} else if (secret_len >= 24) {
			if (!(EVP_EncryptInit_ex(cryptor->ctx,
						 EVP_aes_192_ecb(), NULL,
						 secret, NULL)))
				die("setup aes192 encrypt key failed");
		} else {
			if (!(EVP_EncryptInit_ex(cryptor->ctx,
						 EVP_aes_128_ecb(), NULL,
						 secret, NULL)))
				die("setup aes128 encrypt key failed");
		}

		cryptor->gen_sec_sequence = &gen_sec_sequence_aes;
		}
		break;
	default:
		die("crypto cipher type %d not supported", cryptor->algorithm);
	}

	free(secret);
}

/* init git cryptor or die password not given */
void git_encryptor_init_or_die(git_cryptor *cryptor, int is_pack)
{
	int algo_type;
	char *env;
	int nonce_len;

	if (!agit_crypto_secret)
		die("try encryption but agit.crypto.secret not given");

	env = getenv("GIT_TEST_CRYPTO_ALGORITHM_TYPE");
	if (env && *env != '\0')
		algo_type = atoi(env);
	else if (agit_crypto_default_algorithm)
		algo_type = agit_crypto_default_algorithm;
	else
		algo_type = GIT_CRYPTO_ALGORITHM_DEFAULT;
	nonce_len = is_pack ? crypto_packfile_nonce_length(algo_type) :
			      NONCE_LEN;
	memset(cryptor, 0, sizeof(*cryptor));
	cryptor->algorithm = crypto_new_algorithim(algo_type);
	if (agit_crypto_nonce) {
		int len = strlen(agit_crypto_nonce);
		if (len > nonce_len)
			len = nonce_len;
		memcpy(cryptor->nonce, agit_crypto_nonce, len);
	} else {
		if (nonce_len == NONCE_LEN) { /* Has longer nonce (12 bytes) */
			uint64_t *tm = (uint64_t *)(cryptor->nonce);
			uint32_t *pid = (uint32_t *)(cryptor->nonce+8);
			uint32_t *hdr = (uint32_t *)(cryptor->nonce);
			*tm = getnanotime();
			*pid = (uint32_t)getpid();
			/* Mask for header of nonce: PACK(0x5041434b) or LOSE(0x4c4f5345) */
			*hdr ^= is_pack? 0x5041434b : 0x4c4f5345;
			/* Mask for tailer of nonce: XHTC(0x58485443) or XJYZ(0x584a595a)*/
			*pid ^= is_pack? 0x58485443 : 0x584a595a;
		} else { /* Only 2-byte nonce */
			uint16_t *salt = (uint16_t *)(cryptor->nonce);
			if (!srand_once) {
				srand((unsigned)time(NULL));
				srand_once = 1;
			}
			*salt = (uint16_t)rand();
		}
	}
	git_crypto_setup(cryptor);
}

/*
 * Init git decryptor or die password not given.
 * The input hdr_version is in network byte order.
 */
void git_decryptor_init_or_die(git_cryptor *cryptor,
			       const uint32_t net_hdr_version,
			       unsigned char *nonce)
{
	uint32_t host_hdr_version = ntohl(net_hdr_version) & 0x7FFFFFFF;
	int algo_type;

	if (!agit_crypto_secret) {
		die("try decryption but agit.crypto.secret not given");
	}
	memset(cryptor, 0, sizeof(*cryptor));
	algo_type = host_hdr_version >> 24;

	/* Valid algorithm: 00xx xxxx ~ 010x xxxx */
	cryptor->algorithm = crypto_new_algorithim(algo_type);

	if (!nonce) {
		cryptor->nonce[0] = ((host_hdr_version >> 8) & 0x0000ff);
		cryptor->nonce[1] = ((host_hdr_version >> 16) & 0x0000ff);
	} else {
		memcpy(cryptor->nonce, nonce, NONCE_LEN);
	}
	git_crypto_setup(cryptor);
}

/*
 * Return version of encrypted packet in "host byte order" for packfile,
 * The 4-byte version has different format for different algorithm :
 *
 * For algorithm 1 - 63:
 *  + the 1st byte     : algorithm type
 *  + the 2nd/3rd byte : reserved
 *  + the 4th byte     : PACK_VERSION
 *
 * For algorithm 64 - 95:
 *  + the 1st byte     : algorithm type
 *  + the 2nd/3rd byte : a 2-byte salt
 *  + the 4th byte     : PACK_VERSION
 */
uint32_t git_encryptor_get_host_pack_version(git_cryptor *cryptor,
					     unsigned char *nonce)
{
	uint32_t ret = 0x80000000 | PACK_VERSION;

	if (cryptor->algorithm > 96)
		die("unimplemented encrypt algorithm: %d", cryptor->algorithm);
	ret |= cryptor->algorithm << 24;
	/* 2-byte nonce in header */
	if (crypto_packfile_nonce_length(cryptor->algorithm) == 2) {
		ret |= cryptor->nonce[0] << 8;
		ret |= cryptor->nonce[1] << 16;
	} else if (nonce) {
		memcpy(nonce, cryptor->nonce, NONCE_LEN);
	}
	return ret;
}

/*
 * Return 20 bytes encrypted object header in "network byte order",
 * which include: signature + version
 *
 *  + 4 bytes signature: ENC\0
 *  + 4 bytes version  :
 *      * 1 byte type
 *      * 3 bytes reserved
 *  + 12 bytes nonce
 *
 * Note: If *header is NULL, it's caller's duty to free the allocated header.
 */
unsigned char *git_encryptor_get_net_object_header(git_cryptor *cryptor,
						   unsigned char *header)
{
	uint32_t htonl_version;

	if (header == NULL)
		header = xcalloc(1, GIT_CRYPTO_LO_HEADER_SIZE);
	else
		memset(header, 0, GIT_CRYPTO_LO_HEADER_SIZE);

	memcpy(header, git_crypto_lo_signature, 4);
	htonl_version = htonl(0x80000000 | (cryptor->algorithm << 24));
	memcpy(header + 4, &htonl_version, 4);
	memcpy(header + 8, cryptor->nonce, NONCE_LEN);
	return header;
}
