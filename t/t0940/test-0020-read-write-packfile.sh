#!/bin/sh

# Test read/write encrypted packfile

test_expect_success 'setup' '
	git config agit.crypto.enabled 1 &&
	git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git config agit.crypto.nonce random_nonce
'

test_expect_success 'create commits' '
	test_commit A &&
	test_commit B
'

test_expect_success 'check header of unencrypt packfile' '
	git -c agit.crypto.enabled=0 \
		pack-objects --revs --stdout >packfile.0 <<-\EOF &&
	main
	EOF
	test_copy_bytes 12 <packfile.0 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 50 41 43 4b 00 00 00 02 00 00 00 06                | PACK........     |
	EOF
	test_cmp expect actual
'

# algorithm: benchmark
cat >expect-hdr-1 <<-EOF &&
0000000 50 41 43 4b 81 00 00 02 00 00 00 06 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

# algorithm: aes
cat >expect-hdr-2 <<-EOF &&
0000000 50 41 43 4b 82 00 00 02 00 00 00 06 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect-hdr-64 <<-EOF &&
0000000 50 41 43 4b c0 61 72 02 00 00 00 06                | PACK.ar.....     |
EOF

cat >expect-hdr-65 <<-EOF &&
0000000 50 41 43 4b c1 61 72 02 00 00 00 06                | PACK.ar.....     |
EOF

test_expect_success 'check header of encrypt packfile' '
	git pack-objects --revs --stdout >packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} <<-\EOF &&
	main
	EOF
	show_pack_header <packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'unpack-objects on unencrypted packfile' '
	test_create_repo unpack.0 &&
	git -C unpack.0 unpack-objects <packfile.0
'

test_expect_success 'index-pack on unencrypted packfile' '
	test_create_repo index-pack.0 &&
	pack=$(git -C index-pack.0 index-pack --stdin <packfile.0) &&
	pack=${pack#pack?} &&
	test -f "index-pack.0/.git/objects/pack/pack-$pack.pack"
'

test_expect_success 'verify-pack on uncrypted packfile' '
	git -C index-pack.0 verify-pack .git/objects/pack/pack-$pack.pack
'

test_expect_failure 'unpack-objects on encrypted packfile' '
	test_create_repo unpack.1 &&
	git -C unpack.1 config agit.crypto.enabled 1 &&
	git -C unpack.1 config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git -C unpack.1 config agit.crypto.nonce random_nonce &&
	git -C unpack.1 unpack-objects <packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE}
'

test_expect_failure 'index-pack on encrypted packfile' '
	test_create_repo index-pack.1 &&
	git -C index-pack.1 config agit.crypto.enabled 1 &&
	git -C index-pack.1 config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git -C index-pack.1 config agit.crypto.nonce random_nonce &&
	pack=$(git -C index-pack.1 index-pack \
		--stdin <packfile.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE}) &&
	pack=${pack#pack?} &&
	test -f index-pack.1/.git/objects/pack/pack-$pack.pack
'

test_expect_failure 'verify-pack on encrypted packfile' '
	git -C index-pack.1 verify-pack .git/objects/pack/pack-$pack.pack
'
