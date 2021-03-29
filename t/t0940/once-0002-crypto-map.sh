#!/bin/sh

# Test crypto

test_expect_success 'create simple text file' '
	cat >text-file <<-EOF
	hello, world
	EOF
'

test_expect_success 'compress text file (with --mmap)' '
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

test_expect_success 'uncompress for text file (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		-i text-file.z.0 -o text-file.x.0 &&
	test_cmp text-file text-file.x.0
'

# Base64 is 4*N characters, and after decode will be 3*N characters,
# padding with zero.
#
#     +--------------------------+------------------------------+------------------------------+
#     |          SECRET          |            BASE64            |            DECODE            |
#     +--------------------------+------------------------------+------------------------------+
#     | 12: secret-token         | 16: c2VjcmV0LXRva2Vu         | 12: secret-token             |
#     | 13: secret-token\0       | 20: c2VjcmV0LXRva2VuAA==     | 15: secret-token\0\0\0       |
#     | 14: secret-token\0\0     | 20: c2VjcmV0LXRva2VuAAA=     | 15: secret-token\0\0\0       |
#     | 15: secret-token\0\0\0   | 20: c2VjcmV0LXRva2VuAAAA     | 15: secret-token\0\0\0       |
#     | 16: secret-token\0\0\0\0 | 24: c2VjcmV0LXRva2VuAAAAAA== | 18: secret-token\0\0\0\0\0\0 |
#     +---------------------------------------------------------+------------------------------+
test_expect_success 'encrypt text file using algorithm 1 (with --mmap)' '
	cat >expect-z-1 <<-\EOF &&
	0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 2f 41 6f 66 cf 1a 63 b1 e6 aa cb e2    | once/Aof..c..... |
	0000032 5d e7 6b 2f 57 61 43 2a 91                         | ].k/WaC*.        |
	EOF

	GIT_TEST_CRYPTO_ALGORITHM_TYPE=1 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token" \
		-i text-file -o text-file.z.1 &&
	test-tool agit-od <text-file.z.1 >actual &&
	test_cmp expect-z-1 actual
'

test_expect_success 'encrypt text file using algorithm 2 (with --mmap)' '
	cat >expect-z-2 <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 f2 a6 04 3d 78 ea 79 46 a6 4d f3 d3    | once...=x.yF.M.. |
	0000032 3a b7 b9 ae a2 28 48 8c fc                         | :....(H..        |
	EOF

	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2Vu \
		-i text-file -o text-file.z.2 &&
	test-tool agit-od <text-file.z.2 >actual &&

	! test_cmp expect-z-1 actual &&

	test_cmp expect-z-2 actual
'

test_expect_success 'encrypt text file using algorithm 3 (with --mmap)' '
	cat >expect-z-3 <<-\EOF &&
	0000000 45 4e 43 00 83 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 f2 8b 41 c2 6a 6e 6e 70 9e e7 00 e0    | once..A.jnnp.... |
	0000032 bf 3c 94 77 b5 94 52 b1 b0                         | .<.w..R..        |
	EOF

	GIT_TEST_CRYPTO_ALGORITHM_TYPE=3 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2Vu \
		-i text-file -o text-file.z.3 &&
	test-tool agit-od <text-file.z.3 >actual &&

	! test_cmp expect-z-2 actual &&

	test_cmp expect-z-3 actual
'

test_expect_success 'encrypt text file using algorithm 64 (with --mmap)' '
	show_lo_header <expect-z-1 >expect-z-64 &&
	printf c0 >>expect-z-64 &&
	tail -c 218 <expect-z-1 >>expect-z-64 &&

	GIT_TEST_CRYPTO_ALGORITHM_TYPE=64 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2VuAA== \
		-i text-file -o text-file.z.64 &&
	test-tool agit-od <text-file.z.64 >actual &&
	test_cmp expect-z-64 actual
'

test_expect_success 'encrypt text file using algorithm 65 (with --mmap)' '
	show_lo_header <expect-z-2 >expect-z-65 &&
	printf c1 >>expect-z-65 &&
	tail -c 218 <expect-z-2 >>expect-z-65 &&

	GIT_TEST_CRYPTO_ALGORITHM_TYPE=65 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token" \
		-i text-file -o text-file.z.65 &&
	test-tool agit-od <text-file.z.65 >actual &&

	test_cmp expect-z-65 actual
'

test_expect_success 'encrypt text file using default algorithm (with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE= GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token" \
		-i text-file -o text-file.z.def &&
	test_cmp text-file.z.65 text-file.z.def
'

test_expect_success 'will fail with too short secret (with --mmap)' '
	test_must_fail env GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 \
		GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}pass" \
		-i text-file -o text-file.bad 2>actual &&
	cat >expect <<-\EOF &&
	fatal: secret token is too short
	EOF
	test_cmp expect actual
'

test_expect_success 'encrypt with 12-byte secret (16 effective bytes, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token" \
		-i text-file -o test-file.z.token &&
	test-tool agit-od <test-file.z.token >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 f2 a6 04 3d 78 ea 79 46 a6 4d f3 d3    | once...=x.yF.M.. |
	0000032 3a b7 b9 ae a2 28 48 8c fc                         | :....(H..        |
	EOF
	test_cmp expect actual
'

test_expect_success 'encrypt with 16-byte secret (16 effective bytes, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token--16" \
		-i text-file -o test-file.z.token &&
	test-tool agit-od <test-file.z.token >actual &&

	! test_cmp expect actual &&

	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 c3 20 f1 65 03 13 77 7d 51 66 3b 19    | once. .e..w}Qf;. |
	0000032 2b 53 f2 0a 97 66 e8 6b a4                         | +S. .f.k.        |
	EOF

	test_cmp expect actual
'

test_expect_success 'encrypt with 23-byte secret (same above, 16 effective bytes, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token--16-19--23" \
		-i text-file -o test-file.z.token &&
	test-tool agit-od <test-file.z.token >actual &&

	test_cmp expect actual
'

test_expect_success 'encrypt with 24-byte secret (24 effective bytes, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token--16-19--23-" \
		-i text-file -o test-file.z.token &&
	test-tool agit-od <test-file.z.token >actual &&

	! test_cmp expect actual &&

	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 6e 19 2c 7b 95 f3 91 fd f7 f8 3c ab    | oncen.,{......<. |
	0000032 7a 83 47 2d bb 43 7c 21 65                         | z.G-.C|!e        |
	EOF

	test_cmp expect actual
'

test_expect_success 'encrypt with 26-byte secret (same above, 24 effective bytes, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token--16-19--23-26" \
		-i text-file -o test-file.z.token &&
	test-tool agit-od <test-file.z.token >actual &&

	test_cmp expect actual
'

test_expect_success 'encrypt with 32-byte secret (32 effective bytes, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token--16-19--23-26-29-32" \
		-i text-file -o test-file.z.token &&
	test-tool agit-od <test-file.z.token >actual &&

	! test_cmp expect actual &&

	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65 2f 3d 8a 2c 2d 39 e0 df ab 70 2e 3b    | once/=.,-9...p.; |
	0000032 df 51 7b 9b fc 01 d1 28 17                         | .Q{....(.        |
	EOF
	test_cmp expect actual
'

test_expect_success 'encrypt with 36-byte secret (same above, 32 effective bytes, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret "{plain}secret-token--16-19--23-26-29-32--36" \
		-i text-file -o test-file.z.token &&
	test-tool agit-od <test-file.z.token >actual &&

	test_cmp expect actual
'

test_expect_success 'decrypt text-file.z.1 (bad token, with --mmap)' '
	test_must_fail env GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret YmFkLXRva2VuMTIzNDU2Nw== \
		-i text-file.z.1 -o text-file.x.1.bad
'

test_expect_success 'decrypt text-file.z.1 (bad token, with --mmap)' '
	test_must_fail env GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret "{base64}*BAD*Encode*" \
		-i text-file.z.1 -o bad 2>actual &&
	cat >expect <<-EOF &&
	fatal: decode secret failed
	EOF
	test_cmp expect actual
'

test_expect_success 'decrypt text-file.z.1 (with --mmap)' '
	test_must_fail env GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret "{baseXX}c2VjcmV0LXRva2Vu" \
		-i text-file.z.1 -o bad 2>actual &&
	cat >expect <<-EOF &&
	error: inflate: data stream error (incorrect header check)
	fatal: unable to inflate (-3)
	EOF
	test_cmp expect actual
'

test_expect_success 'decrypt text-file.z.2 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAAA= \
		-i text-file.z.2 -o text-file.x.2 &&

	test_cmp text-file text-file.x.2
'

test_expect_success 'decrypt text-file.z.3 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAAA= \
		-i text-file.z.3 -o text-file.x.3 &&

	test_cmp text-file text-file.x.3
'

test_expect_success 'decrypt text-file.z.64 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAA== \
		-i text-file.z.64 -o text-file.x.64 &&
	test_cmp text-file text-file.x.64
'

test_expect_success 'decrypt text-file.z.64-2 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAAAA \
		-i text-file.z.64 -o text-file.x.64 &&
	test_cmp text-file text-file.x.64
'

test_expect_success 'decrypt text-file.z.64-3 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2Vu \
		-i text-file.z.64 -o text-file.x.64 &&
	test_cmp text-file text-file.x.64
'

test_expect_success 'decrypt text-file.z.65 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2Vu \
		-i text-file.z.65 -o text-file.x.65 &&
	test_cmp text-file text-file.x.65
'

test_expect_success 'decrypt text-file.z.65-2 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAA== \
		-i text-file.z.65 -o text-file.x.65 &&
	test_cmp text-file text-file.x.65
'

test_expect_success 'decrypt text-file.z.65-3 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAAAAAA== \
		-i text-file.z.65 -o text-file.x.65 &&
	test_cmp text-file text-file.x.65
'

test_expect_success NEED_GNU_DD 'create large binary file (10MB, with --mmap)' '
	if type openssl
	then
		openssl enc -aes-256-ctr \
			-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
			-nosalt < /dev/zero | $DD of=bin-file bs=1024 count=10240
	else
		$DD if=/dev/random of=bin-file bs=1024 count=10240
	fi
'

test_expect_success NEED_GNU_DD 'compress binary file (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		-i bin-file -o bin-file.z.0 &&
	test_copy_bytes 2 <bin-file.z.0 |
		test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 78 01                                              | x.               |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'uncompress for binary file (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		-i bin-file.z.0 -o bin-file.x.0 &&
	test_cmp bin-file bin-file.x.0
'

test_expect_success NEED_GNU_DD 'encrypt large binary (algo 1, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=1 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file -o bin-file.z.1 &&
	show_lo_header <bin-file.z.1 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 81 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'encrypt large binary (algo 2, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=2 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file -o bin-file.z.2 &&
	show_lo_header <bin-file.z.2 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 82 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'encrypt large binary (algo 3, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=3 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file -o bin-file.z.3 &&
	show_lo_header <bin-file.z.3 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 83 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'encrypt large binary (algo 64, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=64 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file -o bin-file.z.64 &&
	show_lo_header <bin-file.z.64 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 c0 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'encrypt large binary (algo 65, with --mmap)' '
	GIT_TEST_CRYPTO_ALGORITHM_TYPE=65 GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -z \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file -o bin-file.z.65 &&
	show_lo_header <bin-file.z.65 | test-tool agit-od >actual &&
	cat >expect <<-\EOF &&
	0000000 45 4e 43 00 c1 00 00 00 72 61 6e 64 6f 6d 5f 6e    | ENC.....random_n |
	0000016 6f 6e 63 65                                        | once             |
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'decrypt bin-file.z.1 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file.z.1 -o bin-file.x.1 &&
	test_cmp bin-file bin-file.x.1
'

test_expect_success NEED_GNU_DD 'decrypt bin-file.z.2 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file.z.2 -o bin-file.x.2 &&
	test_cmp bin-file bin-file.x.2
'

test_expect_success NEED_GNU_DD 'decrypt bin-file.z.64 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file.z.64 -o bin-file.x.64 &&
	test_cmp bin-file bin-file.x.64
'

test_expect_success NEED_GNU_DD 'decrypt bin-file.z.65 (with --mmap)' '
	GIT_TRACE_CRYPTO=1 \
		test-tool agit-crypto --mmap -x \
		--secret c2VjcmV0LXRva2VuAA== \
		-i bin-file.z.65 -o bin-file.x.65 &&
	test_cmp bin-file bin-file.x.65
'
