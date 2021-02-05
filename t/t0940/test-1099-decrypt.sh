#!/bin/sh

# Test crypto on "git-decrypt"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" encrypted.git
'

test_expect_success 'create small text file: blob-foo' '
	cat >blob-foo <<-\EOF
	demo
	EOF
'

cat >expect_1 <<-\EOF &&
0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

cat >expect_2 <<-\EOF &&
0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

cat >expect_64 <<-\EOF &&
0000000 45 4e 43 00 c0 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

cat >expect_65 <<-\EOF &&
0000000 45 4e 43 00 c1 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

test_expect_success 'create loose object from blob-foo' '
	oid=$(git -C encrypted.git hash-object -t blob -w ../blob-foo) &&
	test -f encrypted.git/objects/${oid%${oid#??}}/${oid#??} &&
	test_copy_bytes 20 <encrypted.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect_${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'turn off crypto settings' '
	git -C encrypted.git config agit.crypto.enabled 0 &&
	git -C encrypted.git config --unset agit.crypto.secret &&
	rm -f encrypted.git/objects/pack/pack-*.keep
'

test_expect_success 'failed to run git fsck for encrypted repo' '
	test_must_fail git -C encrypted.git fsck
'

test_expect_success 'git decrypt success' '
	GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.secret=c2VjcmV0LXRva2VuMTIzNA==${SQ}" \
		git -C encrypted.git decrypt
'

test_expect_success 'loose object kept' '
	git -C encrypted.git cat-file -t ${oid}
'

test_expect_success 'git fsck' '
	git -C encrypted.git fsck
'
