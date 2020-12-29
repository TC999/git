/*
 * crypto wrapper
 */
#include "crypto.h"
#include "pack.h"
#include "config.h"
#include "hash.h"

const char *agit_crypto_secret;
const char *agit_crypto_salt;
int agit_crypto_enabled;
int agit_pack_encrypted = 0;

static uint8_t crypto_new_algorithim(int algo, int block_size)
{
	uint8_t ret = 0x80;

	switch (algo) {
	default:
		die("bad algorithm: %x\n", algo);
		break;
	case GIT_CRYPTO_ALGORITHM_SIMPLE:
		ret |= algo;
		break;
	}

	switch (block_size) {
	default:
		die("bad algorithm: %x\n", algo);
		break;
	case GIT_CRYPTO_BLOCK_SIZE_32:
	case GIT_CRYPTO_BLOCK_SIZE_1k:
	case GIT_CRYPTO_BLOCK_SIZE_32k:
		ret |= block_size << 4;
		break;
	}

	return ret;
}

static int crypto_get_algorithm(git_cryptor *cryptor)
{
	int algo;

	algo = cryptor->algorithm & 0x0f;

	switch (algo) {
	default:
		die("bad algorithm: %x\n", algo);
		break;
	case GIT_CRYPTO_ALGORITHM_SIMPLE:
		break;
	}
	return algo;
}

/*
 * Setup secret sequence for each block, and returns length of
 * sequence generated.
 */
static int gen_sec_sequence_simple(git_cryptor *cryptor, unsigned char *seq,
				   uint32_t len)
{
	git_SHA256_CTX ctx;
	/* pos = cryptor->byte_counter / 16 */
	uint32_t pos_n = htonl(cryptor->byte_counter >> cryptor->block_shift);
	uint32_t salt_n = htonl(cryptor->salt);
	/* SHA256 writes 32 bytes */
	int ret = 32;
	assert(len >= ret);

	memset(seq, 0, len);
	git_SHA256_Init(&ctx);
	git_SHA256_Update(&ctx, &salt_n, sizeof(uint16_t));
	git_SHA256_Update(&ctx, agit_crypto_secret, strlen(agit_crypto_secret));
	/* different block has different hash */
	git_SHA256_Update(&ctx, &pos_n, sizeof(uint32_t));
	git_SHA256_Final(seq, &ctx);
	return ret;
}

static void git_decrypt_simple(git_cryptor *cryptor, const unsigned char *in,
			unsigned char *out, size_t avail_in, size_t avail_out)
{
	size_t i;
	int sec_seq_init = 0;
	int sec_seq_len;
	/* Must allocate secret_sequence longer enough for HASH function.
	 * SHA256 hash needs 32 bytes.
	 */
	unsigned char secret_sequence[32];

	for (i = 0; i < avail_in && i < avail_out; ++i) {
		if (!sec_seq_init || cryptor->byte_counter % cryptor->block_size == 0) {
			sec_seq_len = cryptor->gen_sec_sequence(
				cryptor, secret_sequence,
				sizeof(secret_sequence));
			sec_seq_init = 1;
		}
		/* encrypt one byte */
		out[i] = in[i] ^
			 secret_sequence[++cryptor->byte_counter % sec_seq_len];
		/* byte_counter overflow? */
		if (cryptor->byte_counter == 0)
			error("encrypt too much data to encrypt securely");
	}
}

static void git_encrypt_simple(git_cryptor *cryptor, const unsigned char *in,
			unsigned char *out, size_t avail_in)
{
	cryptor->decrypt(cryptor, in, out, avail_in, avail_in);
}

/* set up crypto method */
static void git_crypto_setup(git_cryptor *cryptor)
{
	int algo;
	int shift;

	algo = crypto_get_algorithm(cryptor);
	switch (algo) {
	case GIT_CRYPTO_ALGORITHM_SIMPLE:
		cryptor->gen_sec_sequence = &gen_sec_sequence_simple;
		cryptor->encrypt = &git_encrypt_simple;
		cryptor->decrypt = &git_decrypt_simple;
		break;
	default:
		die("crypto ciper type %d not supported", algo);
	}

	algo = (cryptor->algorithm >> 4) & 0x7;
	switch (algo) {
	case GIT_CRYPTO_BLOCK_SIZE_32:
		shift = 5;
		break;
	case GIT_CRYPTO_BLOCK_SIZE_1k:
		shift = 10;
		break;
	case GIT_CRYPTO_BLOCK_SIZE_32k:
		shift = 15;
		break;
	default:
		die("bad block len: %x\n", algo);
		break;
	}
	cryptor->block_shift = shift;
	cryptor->block_size = 1 << shift;
}

/* init git cryptor or die password not given */
void git_encryptor_init_or_die(git_cryptor *cryptor)
{
	int algo_type, algo_block_size;
	char *env;

	if (!agit_crypto_secret)
		die("try encryption but agit.crypto.secret not given");

	env = getenv("GIT_TEST_CRYPTO_ALGORITHM_TYPE");
	if (env)
		algo_type = atoi(env);
	else
		algo_type = GIT_CRYPTO_ALGORITHM_DEFAULT;
	env = getenv("GIT_TEST_CRYPTO_BLOCK_SIZE");
	if (env)
		algo_block_size = atoi(env);
	else
		algo_block_size = GIT_CRYPTO_BLOCK_SIZE_DEFAULT;

	memset(cryptor, 0, sizeof(*cryptor));
	cryptor->algorithm = crypto_new_algorithim(algo_type, algo_block_size);
	if (agit_crypto_salt) {
		if (strlen(agit_crypto_salt) < 2)
			die("input agit_crypto_salt must be at least 2 bytes");
		cryptor->salt = agit_crypto_salt[0] << 8 | agit_crypto_salt[1];
	} else {
		srand((unsigned)time(NULL));
		cryptor->salt = (uint16_t)(rand() % 0xffff);
	}
	git_crypto_setup(cryptor);
}

/*
 * Init git decryptor or die password not given.
 * The input hdr_version is in network byte order.
 */
void git_decryptor_init_or_die(git_cryptor *cryptor,
			       const uint32_t net_hdr_version)
{
	uint32_t host_hdr_version = ntohl(net_hdr_version);

	if (!agit_crypto_secret) {
		die("try decryption but agit.crypto.secret not given");
	}
	memset(cryptor, 0, sizeof(*cryptor));
	cryptor->algorithm = host_hdr_version >> 24;
	cryptor->salt = (host_hdr_version >> 8) & 0x00ffff;
	git_crypto_setup(cryptor);
}

/*
 * Return version of encrypted packet in "host byte order",
 * which has 4 bytes:
 *
 *  + 1 byte cipher-type
 *  + 2 bytes salt
 *  + 1 byte PACK_VERSION
 */
uint32_t git_encryptor_get_host_pack_version(git_cryptor *cryptor)
{
	return cryptor->algorithm << 24 | cryptor->salt << 8 | PACK_VERSION;
}

/*
 * Return 8 bytes encrypted object header in "network byte order",
 * which include: signature + version
 *
 *  + 4 bytes signature: ENC\0
 *  + 4 bytes version  :
 *      * 1 byte type
 *      * 2 bytes salt
 *      * 1 byte reserved
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
	htonl_version = htonl(cryptor->algorithm << 24 | cryptor->salt << 8);
	memcpy(header + 4, &htonl_version, 4);
	return header;
}
