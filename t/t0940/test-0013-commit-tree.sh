#!/bin/sh

# Test crypto on "git-commit-tree"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'create new commit using commit-tree' '
	test_tick &&
	tree=$(git -C bare.git rev-parse "HEAD^{tree}") &&
	parent=$(git -C bare.git rev-parse "HEAD") &&
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

# algorithm: simple, block size: 32
cat >expect_blob_1_0 <<-EOF
0000000 45 4e 43 00 81 73 61 00 f6 27 96 4c 19 57 ef 82
0000020 7d 9f 1f c6 d7 22 ae c0 52 da ce ea b2 7e 1c f2
0000040 16 2c f7 4b 66 e9 89 28 ec 6a e0 73 67 f2 eb fc
0000060 b2 db f6 56 93 37 2c 6e 1e 5b c5 cb 2b 60 75 2e
0000100 d8 7e e3 76 f3 62 e5 75 4b a4 49 d6 c2 42 45 dc
0000120 9a 4d 9f 11 b6 a2 99 4b 89 dd e2 ea e4 a9 39 86
0000140 c8 b2 86 ae 20 a8 00 7b be 5f 7e 41 97 a6 bf 7a
0000160 5d f2 4a 51 36 9f e5 8a 15 af e1 75 44 2b 5e 08
0000200 d2 e5 4f 5d 3b 15 4e b1 ba 2a 80 4b 09 ab da 40
0000220 48 2e 5d c3 77 d6 d7 bb 7d 64 a4 05 29 94 60 dc
0000240 5d e1 47 08 60 bd 83 97 f9 e1 c2 60 7f 12 db e4
0000260 09 21 2c 5a ff
0000265
EOF

# algorithm: simple, block size: 1k
cat >expect_blob_1_1 <<-EOF
0000000 45 4e 43 00 91 73 61 00 f6 27 96 4c 19 57 ef 82
0000020 7d 9f 1f c6 d7 22 ae c0 52 da ce ea b2 7e 1c f2
0000040 16 2c f7 4b 66 e9 89 28 9e 77 ec 1d 44 d7 76 2b
0000060 a0 3b 32 0e 20 4d ea 24 5c f4 41 73 7d 7b f6 a7
0000100 52 c9 77 c0 c7 b7 4a 6a ad 60 c7 f5 24 9f f5 16
0000120 17 b9 40 70 48 16 93 9c 3c 7b 6d 8a 29 03 42 79
0000140 e9 1c 65 4f 59 2c 8f 83 e7 d2 be e1 7f c1 19 3b
0000160 37 13 c1 aa 34 38 0a 74 4c fc 18 d1 f9 27 30 49
0000200 8d 39 cd ac 49 42 d7 8f 80 5f 16 4b fa 41 8f c1
0000220 7f c0 2c 19 9b 67 b4 0d 9e d4 b3 6c 3b ba d4 cb
0000240 e5 a4 f8 ce d8 14 0c ce 96 e4 e8 88 1f a9 0a 49
0000260 6d e3 43 6b e8
0000265
EOF

# algorithm: simple, block size: 32k
cat >expect_blob_1_2 <<-EOF
0000000 45 4e 43 00 a1 73 61 00 f6 27 96 4c 19 57 ef 82
0000020 7d 9f 1f c6 d7 22 ae c0 52 da ce ea b2 7e 1c f2
0000040 16 2c f7 4b 66 e9 89 28 9e 77 ec 1d 44 d7 76 2b
0000060 a0 3b 32 0e 20 4d ea 24 5c f4 41 73 7d 7b f6 a7
0000100 52 c9 77 c0 c7 b7 4a 6a ad 60 c7 f5 24 9f f5 16
0000120 17 b9 40 70 48 16 93 9c 3c 7b 6d 8a 29 03 42 79
0000140 e9 1c 65 4f 59 2c 8f 83 e7 d2 be e1 7f c1 19 3b
0000160 37 13 c1 aa 34 38 0a 74 4c fc 18 d1 f9 27 30 49
0000200 8d 39 cd ac 49 42 d7 8f 80 5f 16 4b fa 41 8f c1
0000220 7f c0 2c 19 9b 67 b4 0d 9e d4 b3 6c 3b ba d4 cb
0000240 e5 a4 f8 ce d8 14 0c ce 96 e4 e8 88 1f a9 0a 49
0000260 6d e3 43 6b e8
0000265
EOF

test_expect_success POSIX 'new commit should be encrypted' '
	od -t x1 bare.git/objects/${X%${X#??}}/${X#??} |
		perl -pe "s/[ \t]+/ /g"  | sed -e "s/ *$//g" >actual &&
	test_cmp expect_blob_${GIT_TEST_CRYPTO_ALGORITHM_TYPE}_${GIT_TEST_CRYPTO_BLOCK_SIZE} actual
'
