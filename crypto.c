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

/*
 * The 1st bit is always 1, which indicates pack or loose object is encrypted.
 */
static uint8_t crypto_new_algorithim(enum agit_crypto_algo algo)
{
	uint8_t ret = 0x80;

	switch (algo) {
	default:
		die("bad algorithm: %x\n", algo);
		break;
	case GIT_CRYPTO_ALGORITHM_HASH:
		ret |= algo;
		break;
	case GIT_CRYPTO_ALGORITHM_AES:
		ret |= algo;
		break;
	}

	return ret;
}

static enum agit_crypto_algo crypto_get_algorithm(git_cryptor *cryptor)
{
	enum agit_crypto_algo algo;

	algo = cryptor->algorithm & 0x7f;

	switch (algo) {
	default:
		die("bad algorithm: %x\n", algo);
		break;
	case GIT_CRYPTO_ALGORITHM_HASH:
		break;
	case GIT_CRYPTO_ALGORITHM_AES:
		break;
	}
	return algo;
}

/*
 * Setup secret sequence for each block, and returns length of
 * sequence generated.
 */
static int gen_sec_sequence_hash(git_cryptor *cryptor, unsigned char *seq,
				 uint32_t len)
{
	git_SHA256_CTX ctx;
	/* pos = cryptor->byte_counter / 32 */
	uint32_t pos_n = htonl(cryptor->byte_counter >> 5);
	int ret = 32;
	/* SHA256 writes 32 bytes */
	assert(len >= ret);

	if (pos_n > 0 && pos_n == cryptor->pos_n_last)
		return ret;
	else
		cryptor->pos_n_last = pos_n;

	git_SHA256_Init(&ctx);
	git_SHA256_Update(&ctx, cryptor->nonce, NONCE_LEN);
	git_SHA256_Update(&ctx, agit_crypto_secret, strlen(agit_crypto_secret));
	/* different block has different hash */
	git_SHA256_Update(&ctx, &pos_n, sizeof(uint32_t));
	git_SHA256_Final(seq, &ctx);
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

	if (pos_n > 0 && pos_n == cryptor->pos_n_last)
		return ret;
	else
		cryptor->pos_n_last = pos_n;

	memcpy(cryptor->nonce + NONCE_LEN, &pos_n, sizeof(uint32_t));

	if (1 != EVP_EncryptUpdate(cryptor->ctx, seq, &ciphertext_len, (const unsigned char *)cryptor->nonce, ret))
		die("aes encrypt nonce failed");
	assert(ciphertext_len == ret);
	return ret;
}

static void git_decrypt(git_cryptor *cryptor, const unsigned char *in,
			unsigned char *out, size_t avail_in, size_t avail_out)
{
	int sec_seq_init = 0, sec_seq_len, i, pos, pos_avali;
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

		pos_avali = (sec_seq_len - pos) < avail ?
			sec_seq_len - pos : avail;

		for (i = 0; i < pos_avali; i++) {
			/* encrypt one byte */
			*out++ = *in++ ^ cryptor->secret_sequence[
				++pos & (sec_seq_len - 1)];
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

/* set up crypto method */
static void git_crypto_setup(git_cryptor *cryptor)
{
	enum agit_crypto_algo algo;

	cryptor->encrypt = &git_encrypt;
	cryptor->decrypt = &git_decrypt;

	algo = crypto_get_algorithm(cryptor);
	switch (algo) {
	case GIT_CRYPTO_ALGORITHM_HASH:
		cryptor->gen_sec_sequence = &gen_sec_sequence_hash;
		break;
	case GIT_CRYPTO_ALGORITHM_AES:
		{
		git_SHA256_CTX ctx;
		unsigned char secret[32];

		/* sha256 secret to make secret to 32 bytes */
		git_SHA256_Init(&ctx);
		git_SHA256_Update(&ctx, agit_crypto_secret, strlen(agit_crypto_secret));
		git_SHA256_Final(secret, &ctx);

		if (!(cryptor->ctx = EVP_CIPHER_CTX_new()))
			die("new aes ctx failed");
		if(1 != EVP_EncryptInit_ex(cryptor->ctx, EVP_aes_256_ecb(), NULL,
				   secret, NULL))
			die("setup aes encrypt key failed");

		cryptor->gen_sec_sequence = &gen_sec_sequence_aes;
		}
		break;
	default:
		die("crypto cipher type %d not supported", algo);
	}
}

/* init git cryptor or die password not given */
void git_encryptor_init_or_die(git_cryptor *cryptor)
{
	int algo_type;
	char *env;

	if (!agit_crypto_secret)
		die("try encryption but agit.crypto.secret not given");

	env = getenv("GIT_TEST_CRYPTO_ALGORITHM_TYPE");
	if (env && *env != '\0')
		algo_type = atoi(env);
	else
		algo_type = GIT_CRYPTO_ALGORITHM_DEFAULT;

	memset(cryptor, 0, sizeof(*cryptor));
	cryptor->algorithm = crypto_new_algorithim(algo_type);
	if (agit_crypto_nonce) {
		int len = strlen(agit_crypto_nonce);
		if (len > NONCE_LEN)
			len = NONCE_LEN;
		memcpy(cryptor->nonce, agit_crypto_nonce, len);
	} else {
		unsigned char *p = cryptor->nonce;
		uint64_t tm = htonll(getnanotime());
		uint32_t pid = htonl((uint32_t)getpid());
		memcpy(p, &tm, 8);
		memcpy(p + NONCE_LEN - 4, &pid, 4);
	}
	git_crypto_setup(cryptor);
}

/*
 * Init git decryptor or die password not given.
 * The input hdr_version is in network byte order.
 */
void git_decryptor_init_or_die(git_cryptor *cryptor,
			       const uint32_t net_hdr_version,
			       unsigned char *nonce, int len)
{
	uint32_t host_hdr_version = ntohl(net_hdr_version);

	if (!agit_crypto_secret) {
		die("try decryption but agit.crypto.secret not given");
	}
	memset(cryptor, 0, sizeof(*cryptor));
	cryptor->algorithm = host_hdr_version >> 24;
	if (len > NONCE_LEN)
		len = NONCE_LEN;
	memcpy(cryptor->nonce, nonce, len);
	git_crypto_setup(cryptor);
}

/*
 * Return version of encrypted packet in "host byte order",
 * which has 4 bytes:
 *
 *  + 1 byte cipher-type
 *  + 3 byte PACK_VERSION
 */
uint32_t git_encryptor_get_host_pack_version(git_cryptor *cryptor)
{
	return cryptor->algorithm << 24 | PACK_VERSION;
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
	htonl_version = htonl(cryptor->algorithm << 24);
	memcpy(header + 4, &htonl_version, 4);
	memcpy(header + 8, cryptor->nonce, NONCE_LEN);
	return header;
}
