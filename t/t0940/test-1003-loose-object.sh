#!/bin/sh

# Test loose objects of an encrypted repository

test_expect_success 'setup' '
	(
		git init --bare normal.git &&
		cd normal.git &&
		git config receive.unpackLimit 100
	) &&
	(
		git init --bare encrypt.git &&
		cd encrypt.git &&
		git config receive.unpackLimit 100 &&
		git config agit.crypto.enabled 1 &&
		git config agit.crypto.secret nekot-terces &&
		git config agit.crypto.nonce random_nonce
	) &&
	git init workdir &&
	printf "demo\n" >workdir/README.txt &&
	git -C workdir add README.txt &&
	test_tick &&
	git -C workdir commit -m "Initial" &&
	oid=$(git -C workdir rev-parse HEAD:README.txt)
'

test_expect_success 'push to normal.git' '
	(
		cd workdir &&
		git push ../normal.git master
	)
'

test_expect_success 'push to encrypt.git' '
	(
		cd workdir &&
		git push ../encrypt.git master
	)
'

cat >expect-hdr-normal <<-\EOF
	0000000 78 01                                              | x.               |
	EOF

cat >expect-hdr-algo-1 <<-\EOF
	0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF

cat >expect-hdr-algo-2 <<-\EOF
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF

########## blob ##########
test_expect_success 'hexdump of blob (normal)' '
	head -c 2 normal.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-normal actual
'

test_expect_success 'hexdump of blob (encrypt)' '
	head -c 20 encrypt.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

########## commit ##########
test_expect_success 'hexdump of commit (normal)' '
	oid=$(git -C workdir rev-parse HEAD) &&
	head -c 2 normal.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-normal actual
'

test_expect_success 'hexdump of commit (encrypt)' '
	head -c 20 encrypt.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

########## tree ##########
test_expect_success 'hexdump of tree (normal)' '
	oid=$(git -C workdir rev-parse "HEAD^{tree}") &&
	head -c 2 normal.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-normal actual
'

test_expect_success 'hexdump of tree (encrypt)' '
	head -c 20 encrypt.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-algo-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'fsck ok for normal.git' '
	git -C normal.git fsck
'

test_expect_success 'fsck ok for normal.git with encrypt settigns' '
	GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.enabled=1${SQ} ${SQ}agit.crypto.secret=nekot-terces${SQ}" \
		git -C normal.git fsck
'

test_expect_success 'fsck ok for encrypt.git' '
	git -C encrypt.git fsck
'

test_expect_success 'turn off crypto settings' '
	git -C encrypt.git config agit.crypto.enabled 0 &&
	git -C encrypt.git config --unset agit.crypto.secret
'

test_expect_success 'fail to fsck on encrypted loose objects without proper config' '
	test_must_fail git -C encrypt.git fsck
'

test_expect_success 'set crypto config using GIT_CONFIG_PARAMETERS' '
	GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.enabled=1${SQ} ${SQ}agit.crypto.secret=nekot-terces${SQ}" \
		git -C encrypt.git fsck
'

test_expect_success 'fail to fsck on encrypted loose object with bad secret' '
	test_must_fail env GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.enabled=1${SQ} ${SQ}agit.crypto.secret=bad-secret${SQ}" \
		git -C encrypt.git fsck
'
