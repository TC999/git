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
		git config agit.crypto.salt sa
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

########## blob ##########
cat >expect_blob_normal <<-EOF
	0000000 78 01 4b ca c9 4f 52 30 65 48 49 cd cd e7 02 00
	0000020 19 3a 03 a4
	0000024
	EOF

# algorithm: simple, block size: 32
cat >expect_blob_encrypt_1_0 <<-EOF
	0000000 45 4e 43 00 81 73 61 00 f6 27 58 09 1b 12 7f 82
	0000020 08 92 0b ec 31 23 ab ea d2 c4 00 4d
	0000034
	EOF

# algorithm: simple, block size: 1k
cat >expect_blob_encrypt_1_1 <<-EOF
	0000000 45 4e 43 00 91 73 61 00 f6 27 58 09 1b 12 7f 82
	0000020 08 92 0b ec 31 23 ab ea d2 c4 00 4d
	0000034
	EOF

# algorithm: simple, block size: 32k
cat >expect_blob_encrypt_1_2 <<-EOF
	0000000 45 4e 43 00 a1 73 61 00 f6 27 58 09 1b 12 7f 82
	0000020 08 92 0b ec 31 23 ab ea d2 c4 00 4d
	0000034
	EOF

test_expect_success POSIX 'hexdump of blob (normal)' '
	od -t x1 normal.git/objects/${oid%${oid#??}}/${oid#??} |
		perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	test_cmp expect_blob_normal actual
'

test_expect_success POSIX 'hexdump of blob (encrypt)' '
	od -t x1 encrypt.git/objects/${oid%${oid#??}}/${oid#??} |
		perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	test_cmp expect_blob_encrypt_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
'

########## commit ##########
cat >expect_commit_normal <<-EOF
	0000000 78 01 85 cd 4d 0a c2 30 10 86 61 d7 39 c5 5c 40
	0000020 99 49 6c 62 a0 88 e2 ca 85 b8 d1 03 e4 67 4a 03
	0000040 8d 91 10 c1 e3 5b 29 b8 75 f7 f2 c0 c7 17 4a ce
	0000060 a9 01 19 5a b5 ca 0c b4 43 1d d9 a3 b6 5a 75 d2
	0000100 6b d2 a6 0b 36 0e 03 62 94 56 b1 8b 1e 25 6f 51
	0000120 b8 57 1b 4b 85 23 dc e1 f6 8d 7e 81 03 bf 5d 7e
	0000140 4e bc 09 25 ef 81 88 a4 25 b2 56 c1 1a 0d a2 98
	0000160 75 be 6b 5c e1 04 57 b8 2c d9 ff f4 cf 5a 9c 1f
	0000200 a9 25 37 89 0f 78 a2 36 68
	0000211
	EOF

# algorithm: simple, block size: 32
cat >expect_commit_encrypt_1_0 <<-EOF
	0000000 45 4e 43 00 81 73 61 00 f6 27 96 0e 9f 57 ef 82
	0000020 7d 5c 23 f6 c5 01 f5 aa 52 b7 6f 8b 98 de 50 ed
	0000040 1e ea 66 56 d1 9a 4f be 71 aa 0f 6c 12 23 99 dd
	0000060 0a cd 74 b9 88 a9 25 6e 20 50 9e 0b db 87 3d 1a
	0000100 52 f8 fa 40 b7 72 df 70 03 30 3b eb 02 8e 9e 1a
	0000120 74 78 2c cb 1c 55 cc 6c c6 0f 97 c2 70 df 15 39
	0000140 4c 71 2a 35 4f c6 d7 3b 99 17 da 46 d5 bb 03 57
	0000160 22 89 9f 1b e4 6e e4 8c e7 13 91 11 64 5e 8b de
	0000200 e8 57 ca 50 88 f0 00 9c 1d 76 b2 4a 2e cf da 05
	0000220 32
	0000221
	EOF

# algorithm: simple, block size: 1k
cat >expect_commit_encrypt_1_1 <<-EOF
	0000000 45 4e 43 00 91 73 61 00 f6 27 96 0e 9f 57 ef 82
	0000020 7d 5c 23 f6 c5 01 f5 aa 52 b7 6f 8b 98 de 50 ed
	0000040 1e ea 66 56 d1 9a 4f be 03 b7 03 02 31 06 04 0a
	0000060 18 2d b0 e1 3b d3 e3 24 62 ff 1a b3 8d 9c be 93
	0000100 d8 4f 6e f6 83 a7 70 6f e5 f4 b5 c8 e4 53 2e d0
	0000120 f9 8c f3 aa e2 e1 c6 bb 73 a9 18 a2 bd 75 6e c6
	0000140 6d df c9 d4 36 42 58 c3 c0 9a 1a e6 3d dc a5 16
	0000160 48 68 14 e0 e6 c9 0b 72 be 40 68 b5 d9 52 e5 9f
	0000200 b7 8b 48 a1 fa a7 99 a2 27 03 24 4a dd 25 8f 84
	0000220 05
	0000221
	EOF


# algorithm: simple, block size: 32k
cat >expect_commit_encrypt_1_2 <<-EOF
	0000000 45 4e 43 00 a1 73 61 00 f6 27 96 0e 9f 57 ef 82
	0000020 7d 5c 23 f6 c5 01 f5 aa 52 b7 6f 8b 98 de 50 ed
	0000040 1e ea 66 56 d1 9a 4f be 03 b7 03 02 31 06 04 0a
	0000060 18 2d b0 e1 3b d3 e3 24 62 ff 1a b3 8d 9c be 93
	0000100 d8 4f 6e f6 83 a7 70 6f e5 f4 b5 c8 e4 53 2e d0
	0000120 f9 8c f3 aa e2 e1 c6 bb 73 a9 18 a2 bd 75 6e c6
	0000140 6d df c9 d4 36 42 58 c3 c0 9a 1a e6 3d dc a5 16
	0000160 48 68 14 e0 e6 c9 0b 72 be 40 68 b5 d9 52 e5 9f
	0000200 b7 8b 48 a1 fa a7 99 a2 27 03 24 4a dd 25 8f 84
	0000220 05
	0000221
	EOF

test_expect_success POSIX 'hexdump of commit (normal)' '
	oid=$(git -C workdir rev-parse HEAD) &&
	(
		cd normal.git/objects &&
		od -t x1 ${oid%${oid#??}}/${oid#??} |
			perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g"
	) >actual &&
	test_cmp expect_commit_normal actual
'

test_expect_success POSIX 'hexdump of commit (encrypt)' '
	(
		cd encrypt.git/objects &&
		od -t x1 ${oid%${oid#??}}/${oid#??} |
			perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g"
	) >actual &&
	! test_cmp expect_commit_normal actual &&
	test_cmp expect_commit_encrypt_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
'

########## tree ##########
cat >expect_tree_normal <<-EOF
	0000000 78 01 2b 29 4a 4d 55 30 b6 60 30 34 30 30 33 31
	0000020 51 08 72 75 74 f1 75 d5 2b a9 28 61 10 f5 dc 56
	0000040 b3 74 72 5e c6 e4 13 93 14 af 72 64 d6 d5 4d bf
	0000060 a2 0d 00 45 a6 10 4b
	0000067
	EOF

# algorithm: simple, block size: 32
cat >expect_tree_encrypt_1_0 <<-EOF
	0000000 45 4e 43 00 81 73 61 00 f6 27 38 ea 98 10 78 82
	0000020 db ba 72 15 cc f4 9a db 9a f6 71 9c 4c a7 c7 f2
	0000040 b0 fb 9f 34 25 08 d9 eb 4f 4f 6d f3 37 9c a3 f6
	0000060 6b 95 f4 1d 99 6b 22 1f 2b 5c 87 14 c8 5d 7a
	0000077
	EOF

# algorithm: simple, block size: 1k
cat >expect_tree_encrypt_1_1 <<-EOF
	0000000 45 4e 43 00 91 73 61 00 f6 27 38 ea 98 10 78 82
	0000020 db ba 72 15 cc f4 9a db 9a f6 71 9c 4c a7 c7 f2
	0000040 b0 fb 9f 34 25 08 d9 eb 3d 52 61 9d 14 b9 3e 21
	0000060 79 75 30 45 2a 11 e4 55 69 f3 03 ac 9e 46 f9
	0000077
	EOF

# algorithm: simple, block size: 32k
cat >expect_tree_encrypt_1_2 <<-EOF
	0000000 45 4e 43 00 a1 73 61 00 f6 27 38 ea 98 10 78 82
	0000020 db ba 72 15 cc f4 9a db 9a f6 71 9c 4c a7 c7 f2
	0000040 b0 fb 9f 34 25 08 d9 eb 3d 52 61 9d 14 b9 3e 21
	0000060 79 75 30 45 2a 11 e4 55 69 f3 03 ac 9e 46 f9
	0000077
	EOF

test_expect_success POSIX 'hexdump of tree (normal)' '
	oid=$(git -C workdir rev-parse "HEAD^{tree}") &&
	(
		cd normal.git/objects &&
		od -t x1 ${oid%${oid#??}}/${oid#??} |
			perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g"
	) >actual &&
	test_cmp expect_tree_normal actual
'

test_expect_success POSIX 'hexdump of tree (encrypt)' '
	(
		cd encrypt.git/objects &&
		od -t x1 ${oid%${oid#??}}/${oid#??} |
			perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g"
	) >actual &&
	! test_cmp expect_tree_normal actual &&
	test_cmp expect_tree_encrypt_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
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
