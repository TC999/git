#!/bin/sh
#
# Copyright (c) 2018 Jiang Xin
#

test_description='Test rate limit for repository fetch'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

bare=bare.git

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

create_commits_in () {
	repo="$1" &&
	if ! parent=$(git -C "$repo" rev-parse HEAD^{} 2>/dev/null)
	then
		parent=
	fi &&
	T=$(git -C "$repo" write-tree) &&
	shift &&
	while test $# -gt 0
	do
		name=$1 &&
		test_tick &&
		if test -z "$parent"
		then
			oid=$(echo $name | git -C "$repo" commit-tree $T)
		else
			oid=$(echo $name | git -C "$repo" commit-tree -p $parent $T)
		fi &&
		eval $name=$oid &&
		parent=$oid &&
		shift ||
		return 1
	done &&
	git -C "$repo" update-ref refs/heads/main $oid
}

get_abbrev_oid () {
	oid=$1 &&
	suffix=${oid#???????} &&
	oid=${oid%$suffix} &&
	if test -n "$oid"
	then
		echo "$oid"
	else
		echo "undefined-oid"
	fi
}

# Format the output of git-push, git-show-ref and other commands to make a
# user-friendly and stable text.  We can easily prepare the expect text
# without having to worry about future changes of the commit ID and spaces
# of the output.  Single quotes are replaced with double quotes, because
# it is boring to prepare unquoted single quotes in expect text.  We also
# remove some locale error messages. The emitted human-readable errors are
# redundant to the more machine-readable output the tests already assert.
make_user_friendly_and_stable_output () {
	sed \
		-e "s/$(get_abbrev_oid $A)[0-9a-f]*/<COMMIT-A>/g" \
		-e "s/$(get_abbrev_oid $B)[0-9a-f]*/<COMMIT-B>/g" \
		-e "s/$(get_abbrev_oid $C)[0-9a-f]*/<COMMIT-C>/g"
}

test_expect_success setup '
	create_bare_repo "$bare" &&
	git -C "$bare" config core.abbrev 7 &&
	git -C "$bare" config agit.loadavgEnabled 1 &&
	create_commits_in "$bare" A B C
'

test_expect_success "clone ok without rate limit" '
	env \
		AGIT_LOADAVG_SOFT_LIMIT=200 \
		AGIT_LOADAVG_HARD_LIMIT=400 \
		AGIT_LOADAVG_RETRY=3 \
		AGIT_LOADAVG_TEST_DRYRUN=1 \
		AGIT_LOADAVG_TEST_MOCK=30 \
		git clone --no-local $bare workcopy >actual 2>&1 &&
	cat >expect <<-\EOF &&
		Cloning into '"'"'workcopy'"'"'...
	EOF
	test_cmp expect actual &&
	test -d workcopy &&
	git -C workcopy log --oneline >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect <<-\EOF &&
		<COMMIT-C> C
		<COMMIT-B> B
		<COMMIT-A> A
	EOF
	test_cmp expect actual &&
	rm -rf workcopy
'

test_expect_success "clone failed: hard limit" '
	test_must_fail env \
		AGIT_LOADAVG_SOFT_LIMIT=200 \
		AGIT_LOADAVG_HARD_LIMIT=400 \
		AGIT_LOADAVG_RETRY=3 \
		AGIT_LOADAVG_TEST_DRYRUN=1 \
		AGIT_LOADAVG_TEST_MOCK=220,350,500 \
		git -c agit.loadavgEnabled=false clone --no-local $bare workcopy >out 2>&1 &&
	sed -e "s/[0-9][0-9]* seconds/xx seconds/g" -e "s/  *$//g" < out >actual &&

	grep "^remote:" actual >actual.1 &&
	cat >expect.1 <<-\EOF &&
		remote: WARN: Server load (220%) is high, waiting xx seconds [loop 1/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 2/3]...
		remote: WARN: Will sleep xx seconds...
		remote: ERROR: Server load (500%) is too high, quilt
	EOF
	test_cmp expect.1 actual.1 &&

	grep "fatal: failed to wait_for_avail_loadavg" actual &&
	grep "fatal: fetch-pack: invalid index-pack output" actual &&

	test ! -d workcopy
'

test_expect_success "clone failed: all soft limit" '
	test_must_fail env \
		AGIT_LOADAVG_SOFT_LIMIT=200 \
		AGIT_LOADAVG_HARD_LIMIT=400 \
		AGIT_LOADAVG_RETRY=3 \
		AGIT_LOADAVG_TEST_DRYRUN=1 \
		AGIT_LOADAVG_TEST_MOCK=220,350 \
		git clone --no-local $bare workcopy >out 2>&1 &&
	sed -e "s/[0-9][0-9]* seconds/xx seconds/g" -e "s/  *$//g" < out >actual &&

	grep "^remote:" actual >actual.1 &&
	cat >expect.1 <<-\EOF &&
		remote: WARN: Server load (220%) is high, waiting xx seconds [loop 1/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 2/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 3/3]...
		remote: WARN: Will sleep xx seconds...
		remote: ERROR: Server load (350%) is still high, quilt
	EOF
	test_cmp expect.1 actual.1 &&

	grep "fatal: failed to wait_for_avail_loadavg" actual &&
	grep "fatal: fetch-pack: invalid index-pack output" actual &&

	test ! -d workcopy
'

test_expect_success "clone ok: 3 soft limit, and ok" '
	env \
		AGIT_LOADAVG_SOFT_LIMIT=200 \
		AGIT_LOADAVG_HARD_LIMIT=400 \
		AGIT_LOADAVG_RETRY=3 \
		AGIT_LOADAVG_TEST_DRYRUN=1 \
		AGIT_LOADAVG_TEST_MOCK=220,350,380,100 \
		git clone --no-local $bare workcopy >out 2>&1 &&
	sed -e "s/[0-9][0-9]* seconds/xx seconds/g" -e "s/  *$//g" < out >actual &&
	cat >expect <<-\EOF &&
		Cloning into '"'"'workcopy'"'"'...
		remote: WARN: Server load (220%) is high, waiting xx seconds [loop 1/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 2/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (380%) is high, waiting xx seconds [loop 3/3]...
		remote: WARN: Will sleep xx seconds...
	EOF
	test_cmp expect actual &&
	test -d workcopy
'

test_expect_success "check clone history, and cleanup" '
	(
		cd workcopy &&
		git log --oneline
	) >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect <<-\EOF &&
		<COMMIT-C> C
		<COMMIT-B> B
		<COMMIT-A> A
	EOF
	test_cmp expect actual &&
	rm -r workcopy
'

test_expect_success "fetch ok without rate limit" '
	test_create_repo workcopy &&
	(
		cd workcopy &&
		git remote add origin ../$bare &&
		env \
			AGIT_LOADAVG_SOFT_LIMIT=200 \
			AGIT_LOADAVG_HARD_LIMIT=400 \
			AGIT_LOADAVG_RETRY=3 \
			AGIT_LOADAVG_TEST_DRYRUN=1 \
			AGIT_LOADAVG_TEST_MOCK=30 \
			git fetch origin 2>&1 &&
			git merge --ff-only origin/main
	) >actual &&
	cat >expect <<-\EOF &&
		From ../bare
		 * [new branch]      main       -> origin/main
	EOF
	test_cmp expect actual &&
	test -d workcopy &&
	git -C workcopy log --oneline >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect <<-\EOF &&
		<COMMIT-C> C
		<COMMIT-B> B
		<COMMIT-A> A
	EOF
	test_cmp expect actual &&
	rm -rf workcopy
'

test_expect_success "fetch failed: hard limit" '
	test_create_repo workcopy &&
	(
		cd workcopy &&
		git remote add origin ../$bare &&
		test_must_fail env \
			AGIT_LOADAVG_SOFT_LIMIT=200 \
			AGIT_LOADAVG_HARD_LIMIT=400 \
			AGIT_LOADAVG_RETRY=3 \
			AGIT_LOADAVG_TEST_DRYRUN=1 \
			AGIT_LOADAVG_TEST_MOCK=220,350,500 \
			git fetch origin 2>&1
	) >out &&
	sed -e "s/[0-9][0-9]* seconds/xx seconds/g" -e "s/  *$//g" < out >actual &&

	grep "^remote:" actual >actual.1 &&
	cat >expect.1 <<-\EOF &&
		remote: WARN: Server load (220%) is high, waiting xx seconds [loop 1/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 2/3]...
		remote: WARN: Will sleep xx seconds...
		remote: ERROR: Server load (500%) is too high, quilt
	EOF
	test_cmp expect.1 actual.1 &&

	grep "fatal: failed to wait_for_avail_loadavg" actual &&
	grep "fatal: protocol error: bad pack header" actual &&

	find workcopy/.git/objects -type f >actual &&
	test_line_count = 0 actual
'

test_expect_success "fetch failed: all soft limit" '
	rm -rf workcopy &&
	test_create_repo workcopy &&
	(
		cd workcopy &&
		git remote add origin ../$bare &&
		test_must_fail env \
			AGIT_LOADAVG_SOFT_LIMIT=200 \
			AGIT_LOADAVG_HARD_LIMIT=400 \
			AGIT_LOADAVG_RETRY=3 \
			AGIT_LOADAVG_TEST_DRYRUN=1 \
			AGIT_LOADAVG_TEST_MOCK=220,350 \
			git fetch origin 2>&1
	) >out &&
	sed -e "s/[0-9][0-9]* seconds/xx seconds/g" -e "s/  *$//g" < out >actual &&

	grep "^remote:" actual >actual.1 &&
	cat >expect.1 <<-\EOF &&
		remote: WARN: Server load (220%) is high, waiting xx seconds [loop 1/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 2/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 3/3]...
		remote: WARN: Will sleep xx seconds...
		remote: ERROR: Server load (350%) is still high, quilt
	EOF
	test_cmp expect.1 actual.1 &&

	grep "fatal: failed to wait_for_avail_loadavg" actual &&
	grep "fatal: protocol error: bad pack header" actual &&

	find workcopy/.git/objects -type f >actual &&
	test_line_count = 0 actual
'

test_expect_success "fetch ok: 3 soft limit, and ok" '
	rm -rf workcopy &&
	test_create_repo workcopy &&
	(
		cd workcopy &&
		git remote add origin ../$bare &&
		env \
			AGIT_LOADAVG_SOFT_LIMIT=200 \
			AGIT_LOADAVG_HARD_LIMIT=400 \
			AGIT_LOADAVG_RETRY=3 \
			AGIT_LOADAVG_TEST_DRYRUN=1 \
			AGIT_LOADAVG_TEST_MOCK=220,350,380,100 \
			git fetch origin 2>&1 &&
			git merge --ff-only origin/main
	) >out &&
	sed -e "s/[0-9][0-9]* seconds/xx seconds/g" -e "s/  *$//g" < out >actual &&
	cat >expect <<-\EOF &&
		remote: WARN: Server load (220%) is high, waiting xx seconds [loop 1/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (350%) is high, waiting xx seconds [loop 2/3]...
		remote: WARN: Will sleep xx seconds...
		remote: WARN: Server load (380%) is high, waiting xx seconds [loop 3/3]...
		remote: WARN: Will sleep xx seconds...
		From ../bare
		 * [new branch]      main       -> origin/main
	EOF
	test_cmp expect actual
'

test_expect_success "check fetched history, and cleanup" '
	(
		cd workcopy &&
		git log --oneline
	) >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect <<-\EOF &&
		<COMMIT-C> C
		<COMMIT-B> B
		<COMMIT-A> A
	EOF
	test_cmp expect actual &&
	rm -r workcopy
'

test_done
