#!/bin/sh

# Test encrypted loose object

test_expect_success 'create small text file: blob-foo' '
	cat >blob-foo <<-\EOF
	demo
	EOF
'

test_expect_success 'create normal blob object from blob-foo' '
	oid=$(git hash-object -t blob -w blob-foo) &&
	test -f .git/objects/${oid%${oid#??}}/${oid#??} &&
	test_copy_bytes 2 <.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	cat >expect <<-EOF &&
	0000000 78 01                                              | x.               |
	EOF
	test_cmp expect actual
'

test_expect_success 'verify normal blob object' '
	git cat-file -p $oid >actual &&
	test_cmp blob-foo actual
'

test_expect_success 'create commit c1 with blob-bar' '
	git add blob-foo &&
	test_tick &&
	git commit -m blob-foo &&
	c1=$(git rev-parse HEAD)
'

test_expect_success 'same oid for commit c1' '
	cat >expect <<-EOF &&
	$oid
	EOF
	git rev-parse $c1:blob-foo >actual &&
	test_cmp expect actual
'

test_expect_success 'check object header for commit c1' '
	test_copy_bytes 2 <.git/objects/${c1%${c1#??}}/${c1#??} |
		test-tool agit-od >actual &&
	cat >expect <<-EOF &&
	0000000 78 01                                              | x.               |
	EOF
	test_cmp expect actual
'

test_expect_success 'fsck on loose objects before encryption' '
	git fsck --strict
'

test_expect_success 'turn on agit.crypto settings' '
	git config agit.crypto.enabled 1 &&
	git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git config agit.crypto.nonce random_nonce
'

# algorithm: benchmark
cat >expect-hdr-1 <<-EOF
0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

# algorithm: aes
cat >expect-hdr-2 <<-EOF
0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

# algorithm: easy_benchmark
cat >expect-hdr-64 <<-EOF
0000000 45 4e 43 00 c0 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

# algorithm: easy_aes
cat >expect-hdr-65 <<-EOF
0000000 45 4e 43 00 c1 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
0000016 6f 6e 63 65                                        | once             |
EOF

test_expect_success 'create small text file: blob-bar' '
	cat >blob-bar <<-\EOF
	hello, world
	EOF
'

test_expect_success 'create small encrypted blob object from blob-bar' '
	oid=$(git hash-object -t blob -w blob-bar) &&
	test -f .git/objects/${oid%${oid#??}}/${oid#??} &&
	show_lo_header <.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success 'fail to restore encrypted blob object with bad token' '
	test_must_fail git -c agit.crypto.secret=bad-token \
		cat-file -p $oid
'

test_expect_success 'verify encrypted blob object for blob-bar' '
	git cat-file -p $oid >actual &&
	test_cmp blob-bar actual
'

test_expect_success 'create commit c2 with blob-bar' '
	git add blob-bar &&
	test_tick &&
	git commit -m blob-bar &&
	c2=$(git rev-parse HEAD)
'

test_expect_success 'same oid for commit c2' '
	cat >expect <<-EOF &&
	$oid
	EOF
	git rev-parse $c2:blob-bar >actual &&
	test_cmp expect actual
'

test_expect_success 'check object header for commit c2' '
	show_lo_header <.git/objects/${c2%${c2#??}}/${c2#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success NEED_GNU_DD 'create small binary file: blob-2m' '
	cat >blob-2m <<-\EOF &&
	blob-2m, which is smaller than 10MB (GIT_CRYPTO_ENCRYPT_LO_MAX_SIZE), will save to
	encrypted loose object.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=2050 >>blob-2m
	else
		$DD if=/dev/random bs=1024 count=2050 >>blob-2m
	fi
'

test_expect_success NEED_GNU_DD 'create encrypted blob object from blob-2m' '
	oid=$(git hash-object -t blob -w blob-2m) &&
	test -f .git/objects/${oid%${oid#??}}/${oid#??} &&
	show_lo_header <.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success NEED_GNU_DD 'verify encrypted large blob object from blob-2m' '
	git cat-file -p $oid >actual &&
	test_cmp blob-2m actual
'

test_expect_success NEED_GNU_DD 'create commit c3 with blob-2m' '
	git add blob-2m &&
	test_tick &&
	git commit -m blob-2m &&
	c3=$(git rev-parse HEAD)
'

test_expect_success NEED_GNU_DD 'same oid for commit c3' '
	cat >expect <<-EOF &&
	$oid
	EOF
	git rev-parse $c3:blob-2m >actual &&
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'check object header for commit c3' '
	show_lo_header <.git/objects/${c3%${c3#??}}/${c3#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success NEED_GNU_DD 'create blob-11m, which larger than GIT_CRYPTO_ENCRYPT_LO_MAX_SIZE)' '
	cat >blob-11m <<-\EOF &&
	blob-11m, which is larger than GIT_CRYPTO_ENCRYPT_LO_MAX_SIZE, will save to
	loose object without encryption.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=11234 >>blob-11m 
	else
		$DD if=/dev/random bs=1024 count=11234 >>blob-11m 
	fi
'

cat >expect <<-EOF
0000000 78 01 00                                           | x..              |
EOF

test_expect_success NEED_GNU_DD 'not encrypt large file: blob-11m' '
	oid=$(git hash-object -t blob -w blob-11m) &&
	test -f .git/objects/${oid%${oid#??}}/${oid#??} &&
	test_copy_bytes 3 <.git/objects/${oid%${oid#??}}/${oid#??} |
		test-tool agit-od >actual &&
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'verify un-encrypted large blob object: blob-11m' '
	git cat-file -p $oid >actual &&
	test_cmp blob-11m actual
'

test_expect_success NEED_GNU_DD 'create commit c4 with blob-11m' '
	git add blob-11m &&
	test_tick &&
	git commit -m blob-11m &&
	c4=$(git rev-parse HEAD)
'

test_expect_success NEED_GNU_DD 'same oid for commit c4' '
	cat >expect <<-EOF &&
	$oid
	EOF
	git rev-parse $c4:blob-11m >actual &&
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'check object header for commit c4' '
	show_lo_header <.git/objects/${c4%${c4#??}}/${c4#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success NEED_GNU_DD 'change core.bigfilethreshold from 512MB (default) to 3MB' '
	git config core.bigfilethreshold 3000000
'

test_expect_success NEED_GNU_DD 'create blob-5m, which larger than bigfilethreshold' '
	cat >blob-5m <<-\EOF &&
	blob-5m, which larger than core.bigfilethreshold, and will be streamed
	directly to packfile.
	EOF
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD bs=1024 count=5000 >>blob-5m
	else
		$DD if=/dev/random bs=1024 count=5000 >>blob-5m
	fi
'

cat >expect-blob-5m <<-EOF
0000000 50 41 43 4b 00 00 00 02                            | PACK....         |
EOF

test_expect_success NEED_GNU_DD 'large blob beyond threshold will not save as loose object' '
	oid=$(git hash-object -t blob -w blob-5m) &&
	test ! -f .git/objects/${oid%${oid#??}}/${oid#??} &&
	PACKID=$(ls ".git/objects/pack/" | grep "pack$") &&
	PACKID=${PACKID%.pack} &&
	PACKID=${PACKID#*pack-}
'

test_expect_success NEED_GNU_DD 'large blob beyond threshold will be saved as packfile (not encrypted)' '
	test_copy_bytes 8 <".git/objects/pack/pack-$PACKID.pack" |
		test-tool agit-od >actual &&
	test_cmp expect-blob-5m actual
'

test_expect_success NEED_GNU_DD 'verify blob-5m, which is larger than bigfilethreshold' '
	git cat-file -p $oid >actual &&
	test_cmp blob-5m actual
'

test_expect_success NEED_GNU_DD 'create commit c5 with blob-5m' '
	git add blob-5m &&
	test_tick &&
	git commit -m blob-5m &&
	c5=$(git rev-parse HEAD)
'

test_expect_success NEED_GNU_DD 'same oid for commit c5' '
	cat >expect <<-EOF &&
	$oid
	EOF
	git rev-parse $c5:blob-5m >actual &&
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'check object header for commit c5' '
	show_lo_header <.git/objects/${c5%${c5#??}}/${c5#??} |
		test-tool agit-od >actual &&
	test_cmp expect-hdr-${GIT_TEST_CRYPTO_ALGORITHM_TYPE} actual
'

test_expect_success NEED_GNU_DD 'fsck on loose objects' '
	git fsck --strict
'
