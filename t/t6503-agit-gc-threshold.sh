#!/bin/sh

test_description='agit-gc threshold test'

. ./test-lib.sh

test_expect_success 'pack size: < 100MB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=1024 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 1024.
	note: agit_gc is disabled for repo size below 100MB.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 100MB ~ 1GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=104857601 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 104857601.
	note: big_pack_threshold is set to 104857600.
	note: pack_size_limit is set to 104857600.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 1GB ~ 3.5GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=1073741825 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 1073741825.
	note: big_pack_threshold is set to 104857600.
	note: pack_size_limit is set to 268435456.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 3.5GB ~ 7.5GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=3758096385 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 3758096385.
	note: big_pack_threshold is set to 268435456.
	note: pack_size_limit is set to 536870912.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 7.5GB ~ 15GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=8053063681 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 8053063681.
	note: big_pack_threshold is set to 536870912.
	note: pack_size_limit is set to 1073741824.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: > 15GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=16106127361 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 16106127361.
	note: big_pack_threshold is set to 1073741824.
	note: pack_size_limit is set to 2147483648.
	EOF
	test_cmp expect actual
'

test_done
