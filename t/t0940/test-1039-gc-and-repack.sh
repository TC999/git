#!/bin/sh

# Test encrypted loose object

test_expect_success 'setup' '
	git config agit.crypto.enabled 1 &&
	git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git config agit.crypto.nonce random_nonce
'

test_expect_success 'create commits' '
	test_commit A &&
	test_commit B
'

cat >expect.algo-1 <<-EOF &&
0000000 50 41 43 4b 81 00 00 02 00 00 00 06 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect.algo-2 <<-EOF &&
0000000 50 41 43 4b 82 00 00 02 00 00 00 06 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect.algo-64 <<-EOF &&
0000000 50 41 43 4b c0 61 72 02 00 00 00 06                | PACK.ar.....     |
EOF

cat >expect.algo-65 <<-EOF &&
0000000 50 41 43 4b c1 61 72 02 00 00 00 06                | PACK.ar.....     |
EOF

test_expect_success 'git gc: create encrypted packfile' '
	git gc &&
	pack=".git/objects/pack/pack-*.pack" &&
	cat $pack | show_pack_header | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'git fsck' '
	git fsck
'

test_expect_success 'create more commits' '
	test_commit C &&
	test_commit D
'

# algorithm: benchmark
cat >expect.algo-1 <<-EOF &&
0000000 50 41 43 4b 81 00 00 02 00 00 00 0c 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

# algorithm: aes
cat >expect.algo-2 <<-EOF &&
0000000 50 41 43 4b 82 00 00 02 00 00 00 0c 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect.algo-64 <<-EOF &&
0000000 50 41 43 4b c0 61 72 02 00 00 00 0c                | PACK.ar.....     |
EOF

cat >expect.algo-65 <<-EOF &&
0000000 50 41 43 4b c1 61 72 02 00 00 00 0c                | PACK.ar.....     |
EOF

test_expect_success 'git repack' '
	git repack -ad &&
	pack=".git/objects/pack/pack-*.pack" &&
	cat $pack | show_pack_header | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect.algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'git fsck after repack' '
	git fsck
'
