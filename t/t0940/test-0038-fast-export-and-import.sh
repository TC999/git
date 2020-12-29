#!/bin/sh

# Test crypto on "git-fast-export-and-import"

test_expect_success 'fast-export' '
	git -C "$COMMON_GITDIR" fast-export --all --full-tree >export.data
'

test_expect_success 'fast-import to normal repo' '
	git init --bare normal.git &&
	(
		cd normal.git &&
		git fast-import <../export.data &&
		git fsck &&
		git log --oneline master |
			make_user_friendly_and_stable_output >actual &&
		cat >expect <<-EOF &&
		<COMMIT-F> Commit-F
		<COMMIT-C> Commit-C
		EOF
		test_cmp expect actual
	)
'

test_expect_success 'fast-import to encrypt repo' '
	git init --bare encrypt.git &&
	(
		cd encrypt.git &&

		# encrypt settings
		git config agit.crypto.enabled 1 &&
		git config agit.crypto.secret nekot-terces &&
		git config agit.crypto.salt sa &&

		git fast-import <../export.data &&
		git fsck &&
		git log --oneline master |
			make_user_friendly_and_stable_output >actual &&
		cat >expect <<-EOF &&
		<COMMIT-F> Commit-F
		<COMMIT-C> Commit-C
		EOF
		test_cmp expect actual
	)
'


# algorithm: simple, block size: 32
cat >expect_1_0 <<-EOF &&
0000000 45 4e 43 00 81 73 61 00 f6 27 58 09 1b 12 7f 82
EOF

# algorithm: simple, block size: 32
cat >expect_1_1 <<-EOF &&
0000000 45 4e 43 00 91 73 61 00 f6 27 58 09 1b 12 7f 82
EOF

# algorithm: simple, block size: 32k
cat >expect_1_2 <<-EOF &&
0000000 45 4e 43 00 a1 73 61 00 f6 27 58 09 1b 12 7f 82
EOF

test_expect_success POSIX 'blob is encrypted' '
	oid=$(git -C encrypt.git rev-parse master:README.txt) &&
	od -t x1 encrypt.git/objects/${oid%${oid#??}}/${oid#??} |
		head -1 |
		perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
'
