#!/bin/sh

# Test crypto on "git-commit-tree"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'create new commit using commit-tree' '
	tree=$(git -C bare.git rev-parse "HEAD^{tree}") &&
	parent=$(git -C bare.git rev-parse "HEAD") &&
	test_tick &&
	X=$(git -C bare.git commit-tree -p "$parent" -m "New commit by commit-tree" "$tree") &&
	git -C bare.git update-ref refs/heads/master $X &&
	git -C bare.git log --pretty="%s" master >actual &&
	cat >expect <<-EOF &&
	New commit by commit-tree
	Commit-F
	Commit-C
	EOF
	test_cmp expect actual
'

# algorithm: hash
cat >expect_blob_1 <<-\EOF
0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

# algorithm: aes
cat >expect_blob_2 <<-\EOF
0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

test_expect_success 'new commit should be encrypted' '
	head -c 20 bare.git/objects/${X%${X#??}}/${X#??} |
		test-tool agit-od >actual &&
	test_cmp expect_blob_${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'
