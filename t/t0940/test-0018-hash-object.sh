#!/bin/sh

# Test crypto on "git-hash-object"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

# algorithm: simple, block size: 32
cat >expect_1_0 <<-EOF &&
0000000 45 4e 43 00 81 73 61 00 f6 27 58 09 1b 12 7f 82
0000020 df ba b2 ed d7 ec 84 bb 83 b7 2f a0 6c 1e 79 08
0000040 c9 9a ff 79 fb 2d c8 f2 36 71 52 83 20 9b b2 65
0000060 a3 62 8d 82
0000064
EOF

# algorithm: simple, block size: 1k
cat >expect_1_1 <<-EOF &&
0000000 45 4e 43 00 91 73 61 00 f6 27 58 09 1b 12 7f 82
0000020 df ba b2 ed d7 ec 84 bb 83 b7 2f a0 6c 1e 79 08
0000040 c9 9a ff 79 fb 2d c8 f2 44 6c 5e ed 03 be 2f b2
0000060 b1 82 49 da
0000064
EOF

# algorithm: simple, block size: 32k
cat >expect_1_2 <<-EOF &&
0000000 45 4e 43 00 a1 73 61 00 f6 27 58 09 1b 12 7f 82
0000020 df ba b2 ed d7 ec 84 bb 83 b7 2f a0 6c 1e 79 08
0000040 c9 9a ff 79 fb 2d c8 f2 44 6c 5e ed 03 be 2f b2
0000060 b1 82 49 da
0000064
EOF

test_expect_success POSIX 'create encrypt blob object using hash-object' '
	cat >data <<-EOF &&
	Input data for hash-object.
	EOF
	oid=$(git -C bare.git hash-object -t blob -w ../data) &&
	test -f bare.git/objects/${oid%${oid#??}}/${oid#??} &&
	od -t x1 bare.git/objects/${oid%${oid#??}}/${oid#??} |
		perl -pe "s/[ \t]+/ /g" | sed -e "s/ *$//g" >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
	
'
