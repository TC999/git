#!/bin/sh

test_description='agit-gc threshold test'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

create_bare_repo () {
	test "$#" = 1 ||
	BUG "not 1 parameter to test-create-repo"
	repo="$1"
	mkdir -p "$repo"
	(
		cd "$repo" || error "Cannot setup test environment"
		git -c \
			init.defaultBranch="${GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME-master}" \
			init --bare \
			"--template=$GIT_BUILD_DIR/templates/blt/" >&3 2>&4 ||
		error "cannot run git init -- have you built things yet?"
		mv hooks hooks-disabled &&
		git config core.abbrev 7
	) || exit
}

test_expect_success 'pack size: < 128MB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=100123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 100123123.
	note: agit_gc is disabled for repo size below 128MB.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: < 128MB (agit.gc=1)' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=100123123 \
		git -c agit.gc=1 gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 100123123.
	note: agit_gc is disabled for repo size below 128MB.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 128MB ~ 2GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=500123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 500123123.
	note: big_pack_threshold is set to 67108864.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 2GB ~ 4GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=3123123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 3123123123.
	note: big_pack_threshold is set to 134217728.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 4GB ~ 8GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=6123123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 6123123123.
	note: big_pack_threshold is set to 268435456.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 8GB ~ 16GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=9123123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 9123123123.
	note: big_pack_threshold is set to 536870912.
	EOF
	test_cmp expect actual
'

test_expect_success 'pack size: 16GB ~ 32GB' '
	AGIT_DEBUG_TOTAL_PACK_SIZE=20123123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	cat >expect <<-EOF &&
	note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 20123123123.
	note: big_pack_threshold is set to 1073741824.
	EOF
	test_cmp expect actual
'

test_expect_success !MINGW,!CYGWIN 'pack size: 32GB ~ 64GB' '
	if uname -a | grep -w i686 || test "$jobname" = "linux32"
	then
		cat >expect <<-EOF
		note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 40123123123.
		note: big_pack_threshold is set to 1789569700.
		EOF
	else
		cat >expect <<-EOF
		note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 40123123123.
		note: big_pack_threshold is set to 2147483648.
		EOF
	fi &&
	AGIT_DEBUG_TOTAL_PACK_SIZE=40123123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	test_cmp expect actual
'

test_expect_success !MINGW,!CYGWIN 'pack size: 64GB ~' '
	if uname -a | grep -w i686 || test "$jobname" = "linux32"
	then
		cat >expect <<-EOF
		note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 80123123123.
		note: big_pack_threshold is set to 1789569700.
		EOF
	else
		cat >expect <<-EOF
		note: AGIT_DEBUG_TOTAL_PACK_SIZE is set to 80123123123.
		note: big_pack_threshold is set to 2147483648.
		EOF
	fi &&
	AGIT_DEBUG_TOTAL_PACK_SIZE=80123123123 \
		git gc --dryrun 2>&1 |
		grep -v "note: will run:" >actual &&
	test_cmp expect actual
'

test_done
