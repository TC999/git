#!/bin/sh

# Test crypto

test_expect_success 'create simple text file' '
	cat >text-file <<-EOF
	hello, world
	EOF
'

test_expect_success 'compress text file (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		-i text-file -o text-file.z.0 &&
	test-tool agit-od <text-file.z.0 >actual &&
	cat >expect <<-\EOF &&
	0000000 78 01 cb 48 cd c9 c9 d7 51 28 cf 2f ca 49 e1 02    | x..H....Q(./.I.. |
	0000016 00 21 e7 04 93                                     | .!...            |
	EOF
	test_cmp expect actual
'

test_expect_success 'uncompress for text file (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		-i text-file.z.0 -o text-file.x.0 &&
	test_cmp text-file text-file.x.0
'

test_expect_success 'encrypt text file using algorithm 1 (use --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=1 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "secret-token" \
		-i text-file -o text-file.z.1 &&
	test-tool agit-od <text-file.z.1 >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 9b eb 28 09 b9 8e d9 d9 9e ae ea a1    | once..( ........ |
	0000032 93 b5 6b be 62 0a 30 d0 ef                         | ..k.b 0..        |
	EOF
	test_cmp expect actual
'

test_expect_success 'encrypt text file using algorithm 2 (use --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "secret-token" \
		-i text-file -o text-file.z.2 &&
	test-tool agit-od <text-file.z.2 >actual &&

	! test_cmp expect actual &&

	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 4d 25 2c 2c 85 e7 e0 fc 1d 58 7e 12    | onceM%,,.....X~. |
	0000032 c3 39 87 c7 dd df ae 3a a3                         | .9.....:.        |
	EOF
	test_cmp expect actual
'

test_expect_success 'encrypt text file using default algorithm (use --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE= GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "secret-token" \
		-i text-file -o text-file.z.def &&
	test_cmp text-file.z.2 text-file.z.def
'

test_expect_success 'decrypt text-file.z.1 (bad token, use --mmap)' '
	test_must_fail env GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret "bad-token" \
		-i text-file.z.1 -o text-file.x.1.bad
'

test_expect_success 'decrypt text-file.z.1 (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret "secret-token" \
		-i text-file.z.1 -o text-file.x.1 &&
	test_cmp text-file text-file.x.1
'

test_expect_success 'decrypt text-file.z.2 (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret "secret-token" \
		-i text-file.z.2 -o text-file.x.2 &&
	test_cmp text-file text-file.x.2
'

test_expect_success NEED_GNU_DD 'create large binary file (10MB)' '
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD of=bin-file bs=1024 count=10240
	else
		$DD if=/dev/random of=bin-file bs=1024 count=10240
	fi
'

test_expect_success NEED_GNU_DD 'compress binary file (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		-i bin-file -o bin-file.z.0 &&
	head -c 3 <bin-file.z.0 |
		test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 78 01 00                                           | x..              |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'uncompress for binary file (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		-i bin-file.z.0 -o bin-file.x.0 &&
	test_cmp bin-file bin-file.x.0
'

test_expect_success NEED_GNU_DD 'encrypt large binary (algo 1, use --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=1 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "secret-token" \
		-i bin-file -o bin-file.z.1 &&
	head -c 20 <bin-file.z.1 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'encrypt large binary (algo 2, use --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "secret-token" \
		-i bin-file -o bin-file.z.2 &&
	head -c 20 <bin-file.z.2 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'decrypt bin-file.z.1 (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret "secret-token" \
		-i bin-file.z.1 -o bin-file.x.1 &&
	test_cmp bin-file bin-file.x.1
'

test_expect_success NEED_GNU_DD 'decrypt bin-file.z.2 (use --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret "secret-token" \
		-i bin-file.z.2 -o bin-file.x.2 &&
	test_cmp bin-file bin-file.x.2
'
