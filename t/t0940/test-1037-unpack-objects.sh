#!/bin/sh

# Test crypto on "git-unpack-objects"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" bare.git &&

	# create test.git and copy agit.crypto settings from bare.git
	create_bare_repo test.git &&
	cp bare.git/config test.git/config
'

cat >expect <<-\EOF &&
0000000 50 41 43 4b 00 00 00 02 00 00 00 03                | PACK........     |
EOF

test_expect_success 'PACK1 is unencrypted' '
	test_copy_bytes 12 <bare.git/objects/pack/pack-$PACK1.pack |
		test-tool agit-od >actual &&
	test_cmp expect actual
'

test_expect_success 'unpack-objects from unencrypted packfile' '
	git -C test.git unpack-objects <bare.git/objects/pack/pack-$PACK1.pack
'

cat >expect_1 <<-\EOF
0000000 50 41 43 4b 81 00 00 02 00 00 00 03 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect_2 <<-\EOF
0000000 50 41 43 4b 82 00 00 02 00 00 00 03 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect_64 <<-\EOF
0000000 50 41 43 4b c0 61 72 02 00 00 00 03                | PACK.ar.....     |
EOF

cat >expect_65 <<-\EOF
0000000 50 41 43 4b c1 61 72 02 00 00 00 03                | PACK.ar.....     |
EOF

test_expect_success 'PACK2 is encrypted' '
	show_pack_header <bare.git/objects/pack/pack-$PACK2.pack |
		test-tool agit-od >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
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
