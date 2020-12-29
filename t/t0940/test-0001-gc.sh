#!/bin/sh

# Test crypto on "git-gc"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success POSIX 'check header of packfile without encryption' '
	head -c 8 bare.git/objects/pack/pack-$PACK1.pack |
		od -t x1 | perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	cat >expect <<-EOF &&
	0000000 50 41 43 4b 00 00 00 02
	0000010
	EOF
	test_cmp expect actual
'

# algorithm: simple, block size: 32
cat >expect_1_0 <<-EOF &&
0000000 50 41 43 4b 81 73 61 02
0000010
EOF

# algorithm: simple, block size: 1k
cat >expect_1_1 <<-EOF &&
0000000 50 41 43 4b 91 73 61 02
0000010
EOF

# algorithm: simple, block size: 32k
cat >expect_1_2 <<-EOF &&
0000000 50 41 43 4b a1 73 61 02
0000010
EOF

test_expect_success POSIX 'check header of encrypted packfile' '
	head -c 8 bare.git/objects/pack/pack-$PACK2.pack |
		od -t x1 | perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
'

test_expect_success 'remove keep files' '
	(
		cd bare.git &&
		rm objects/pack/pack-$PACK1.keep && 
		rm objects/pack/pack-$PACK2.keep
	)
'

test_expect_success 'turn off crypto settings' '
	git -C bare.git config agit.crypto.enabled 0 &&
	git -C bare.git config --unset agit.crypto.secret
'

test_expect_success 'fail to gc on encrypted repo without proper config' '
	test_must_fail git -C bare.git gc
'

test_expect_success 'fail to gc on encrypted repo with bad secret' '
	test_must_fail env GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.enabled=1${SQ} ${SQ}agit.crypto.secret=bad-secret${SQ}" \
		git -C bare.git gc
'

test_expect_success 'gc with crypto config using GIT_CONFIG_PARAMETERS' '
	GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.enabled=1${SQ} ${SQ}agit.crypto.secret=nekot-terces${SQ}" \
		git -C bare.git gc &&
	GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.enabled=1${SQ} ${SQ}agit.crypto.secret=nekot-terces${SQ}" \
		git -C bare.git fsck
'

test_expect_success 'pack1 not exist' '
	test ! -f bare.git/objects/pack/pack-$PACK1.pack
'

test_expect_success 'pack2 not exist' '
	test ! -f bare.git/objects/pack/pack-$PACK2.pack
'

test_expect_success POSIX 'pack to one encrypted file' '
	X=$(ls "bare.git/objects/pack/" | grep "pack$" | sed -e "s/.*pack-\(.*\).pack$/\1/") &&
	head -c 8 bare.git/objects/pack/pack-$X.pack >output &&
		od -t x1 <output | perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
'
