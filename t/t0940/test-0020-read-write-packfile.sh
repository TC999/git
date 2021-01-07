#!/bin/sh

# Test read/write encrypted packfile

test_expect_success 'setup' '
	git config agit.crypto.enabled 1 &&
	git config agit.crypto.secret nekot-terces &&
	git config agit.crypto.nonce random_nonce
'

test_expect_success 'create commits' '
	test_commit A &&
	test_commit B
'

test_expect_success 'check header of unencrypt packfile' '
	git -c agit.crypto.enabled=0 \
		pack-objects --revs --stdout >packfile.0 <<-\EOF &&
	master
	EOF
	head -c 12 packfile.0 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 50 41 43 4b 00 00 00 02 00 00 00 06                | PACK........     |
	EOF
	test_cmp expect actual
'

# algorithm: hash
cat >expect-hdr-1 <<-EOF &&
0000000 50 41 43 4b 81 00 00 02 00 00 00 06 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

# algorithm: aes
cat >expect-hdr-2 <<-EOF &&
0000000 50 41 43 4b 82 00 00 02 00 00 00 06 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

test_expect_success 'check header of encrypt packfile' '
	git pack-objects --revs --stdout >packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} <<-\EOF &&
	master
	EOF
	head -c 24 packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'unpack-objects on unencrypted packfile' '
	git init unpack.0 &&
	git -C unpack.0 unpack-objects <packfile.0
'

test_expect_success 'index-pack on unencrypted packfile' '
	git init index-pack.0 &&
	pack=$(git -C index-pack.0 index-pack --stdin <packfile.0) &&
	pack=${pack#pack?} &&
	test -f "index-pack.0/.git/objects/pack/pack-$pack.pack"
'

test_expect_success 'verify-pack on uncrypted packfile' '
	git -C index-pack.0 verify-pack .git/objects/pack/pack-$pack.pack
'

test_expect_success 'unpack-objects on encrypted packfile' '
	git init unpack.1 &&
	git -C unpack.1 config agit.crypto.enabled 1 &&
	git -C unpack.1 config agit.crypto.secret nekot-terces &&
	git -C unpack.1 config agit.crypto.nonce random_nonce &&
	git -C unpack.1 unpack-objects <packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE}
'

test_expect_success 'index-pack on encrypted packfile' '
	git init index-pack.1 &&
	git -C index-pack.1 config agit.crypto.enabled 1 &&
	git -C index-pack.1 config agit.crypto.secret nekot-terces &&
	git -C index-pack.1 config agit.crypto.nonce random_nonce &&
	pack=$(git -C index-pack.1 index-pack \
		--stdin <packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE}) &&
	pack=${pack#pack?} &&
	test -f index-pack.1/.git/objects/pack/pack-$pack.pack
'

test_expect_success 'fsck on encrypted packfile' '
	git -C index-pack.1 fsck
'

test_expect_success 'verify-pack on encrypted packfile' '
	git -C index-pack.1 verify-pack .git/objects/pack/pack-$pack.pack
'

test_expect_success 'unpack-objects on unencrypted packfile to encrypted loose objects' '
	git init unpack.2 &&
	git -C unpack.2 config agit.crypto.enabled 1 &&
	git -C unpack.2 config agit.crypto.secret nekot-terces &&
	git -C unpack.2 config agit.crypto.nonce random_nonce &&
	git -C unpack.2 unpack-objects <packfile.0
'

test_expect_success 'index-pack on unencrypted packfile to encrypted packfile' '
	git init index-pack.2 &&
	git -C index-pack.2 config agit.crypto.enabled 1 &&
	git -C index-pack.2 config agit.crypto.secret nekot-terces &&
	git -C index-pack.2 config agit.crypto.nonce random_nonce &&
	pack=$(git -C index-pack.2 index-pack --stdin <packfile.0) &&
	pack=${pack#pack?} &&
	test -f index-pack.2/.git/objects/pack/pack-$pack.pack
'

test_expect_success 'fsck on unencrypted packfile to encrypted packfile' '
	git -C index-pack.2 fsck
'

test_expect_success 'verify-pack on unencrypted packfile to encrypted packfile' '
	git -C index-pack.2 verify-pack .git/objects/pack/pack-$pack.pack
'
