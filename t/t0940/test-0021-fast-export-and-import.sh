#!/bin/sh

# Test crypto on "git-fast-export-and-import"

test_expect_success 'create normal commits' '
	test_commit A &&
	test_commit B
'

test_expect_success 'enable encrypt settings' '
	git config agit.crypto.enabled 1 &&
	git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git config agit.crypto.nonce random_nonce
'

test_expect_success 'create encrypted commits' '
	test_commit C &&
	test_commit D
'

test_expect_success 'fast-export' '
	git fast-export --all --full-tree >export.data
'

test_expect_success 'fast-import to normal repo' '
	create_bare_repo normal.git &&
	(
		cd normal.git &&
		git fast-import <../export.data &&
		git fsck &&
		git log --pretty="%s" main >actual &&
		cat >expect <<-EOF &&
		D
		C
		B
		A
		EOF
		test_cmp expect actual
	)
'

test_expect_success 'fast-import encrypt repo' '
	create_bare_repo encrypt-loose.git &&
	(
		cd encrypt-loose.git &&

		# encrypt settings
		git config agit.crypto.enabled 1 &&
		git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
		git config agit.crypto.nonce random_nonce &&

		git fast-import <../export.data &&
		git fsck &&
		git log --pretty="%s" main >actual &&
		cat >expect <<-EOF &&
		D
		C
		B
		A
		EOF
		test_cmp expect actual
	)
'

cat >expect_1 <<-EOF &&
0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

cat >expect_2 <<-EOF &&
0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

cat >expect_64 <<-EOF
0000000 45 4e 43 00 c0 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

cat >expect_65 <<-EOF
0000000 45 4e 43 00 c1 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

test_expect_success 'after import, loose object is encrypted' '
	oid=$(git -C encrypt-loose.git rev-parse main:A.t) &&
	show_lo_header <encrypt-loose.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'git fsck for encrypted loose objects' '
	git -C encrypt-loose.git fsck
'

test_expect_success 'fast-import to encrypt packfile' '
	create_bare_repo encrypt-pack.git &&
	(
		cd encrypt-pack.git &&

		# encrypt settings
		git config agit.crypto.enabled 1 &&
		git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
		git config agit.crypto.nonce random_nonce &&
		git config fastimport.unpacklimit 1 &&

		git fast-import <../export.data &&
		git fsck &&
		git log --pretty="%s" main >actual &&
		cat >expect <<-EOF &&
		D
		C
		B
		A
		EOF
		test_cmp expect actual
	)
'

cat >expect_1 <<-EOF &&
0000000 50 41 43 4b 81 00 00 02 00 00 00 0c 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect_2 <<-EOF &&
0000000 50 41 43 4b 82 00 00 02 00 00 00 0c 72 61 6e 64    | PACK........rand |
0000016 6f 6d 5f 6e 6f 6e 63 65                            | om_nonce         |
EOF

cat >expect_64 <<-EOF &&
0000000 50 41 43 4b c0 61 72 02 00 00 00 0c                | PACK.ar.....     |
EOF

cat >expect_65 <<-EOF &&
0000000 50 41 43 4b c1 61 72 02 00 00 00 0c                | PACK.ar.....     |
EOF

test_expect_failure 'after import, packfile is encrypted' '
	show_pack_header <encrypt-pack.git/objects/pack/pack-*.pack |
		test-tool agit-od >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'git fsck for encrypted packfile' '
	git -C encrypt-pack.git fsck
'
