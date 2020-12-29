#!/bin/sh

# Test crypto on "git-commit-tree"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" bare.git
'

test_expect_success 'create new commit using commit-tree' '
	tree=$(git -C bare.git rev-parse "HEAD^{tree}") &&
	parent=$(git -C bare.git rev-parse "HEAD") &&
	test_tick &&
	oid=$(git -C bare.git commit-tree -p "$parent" -m "New commit by commit-tree" "$tree") &&
	git -C bare.git update-ref refs/heads/main $oid &&
	git -C bare.git log --pretty="%s" main >actual &&
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

cat >expect_blob_64 <<-EOF
0000000 45 4e 43 00 c0 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

cat >expect_blob_65 <<-EOF
0000000 45 4e 43 00 c1 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

test_expect_success 'new commit should be encrypted' '
	show_lo_header <bare.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect_blob_${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'
