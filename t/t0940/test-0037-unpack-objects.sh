#!/bin/sh

# Test crypto on "git-unpack-objects"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git &&

	# create test.git and copy agit.crypto settings from bare.git
	git init --bare test.git &&
	cp bare.git/config test.git/config
'

cat >expect <<-EOF &&
0000000 50 41 43 4b 00 00 00 02
0000010
EOF

test_expect_success POSIX 'PACK1 is unencrypted' '
	head -c 8 bare.git/objects/pack/pack-$PACK1.pack |
		od -t x1 |
		perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	test_cmp expect actual
'

test_expect_success 'unpack-objects from unencrypted packfile' '
	git -C test.git unpack-objects <bare.git/objects/pack/pack-$PACK1.pack
'

test_expect_success POSIX 'PACK2 is encrypted' '
	head -c 8 bare.git/objects/pack/pack-$PACK2.pack |
		od -t x1 |
		perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	! test_cmp expect actual
'

test_expect_success 'unpack-objects from encrypted packfile' '
	git -C test.git unpack-objects <bare.git/objects/pack/pack-$PACK2.pack
'

test_expect_success 'check history' '
	git -C test.git log --oneline $F |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> Commit-F
	<COMMIT-C> Commit-C
	EOF
	test_cmp expect actual
'
