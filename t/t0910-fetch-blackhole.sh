#!/bin/sh
#
# Copyright (c) 2019 Jiang Xin
#

test_description='Test git clone/fetch --black-hole'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

bare=bare-repo.git

if test $(uname -s) = "Darwin"; then
	STAT_PROGRAM=gstat
else
	STAT_PROGRAM=stat
fi

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
		-e "s/$(get_abbrev_oid $C)[0-9a-f]*/<COMMIT-C>/g" \
		-e "s/$(get_abbrev_oid $D)[0-9a-f]*/<COMMIT-D>/g" \
		-e "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" \
		-e "s/$(get_abbrev_oid $F)[0-9a-f]*/<COMMIT-F>/g" \
		-e "s/$(get_abbrev_oid $G)[0-9a-f]*/<COMMIT-G>/g" \
		-e "s/$(get_abbrev_oid $H)[0-9a-f]*/<COMMIT-H>/g" \
		-e "s/$(get_abbrev_oid $I)[0-9a-f]*/<COMMIT-I>/g" \
		-e "s/$(get_abbrev_oid $J)[0-9a-f]*/<COMMIT-J>/g" \
		-e "s/$(get_abbrev_oid $K)[0-9a-f]*/<COMMIT-K>/g" \
		-e "s/$(get_abbrev_oid $TAG1)[0-9a-f]*/<TAG-1>/g" \
		-e "s/$(get_abbrev_oid $TAG2)[0-9a-f]*/<TAG-2>/g"
}

test_expect_success setup '
	create_bare_repo "$bare" &&
	create_commits_in "$bare" A B C D E F G H I J K &&
	git -C "$bare" update-ref refs/heads/test $B &&
	test_tick &&
	git -C "$bare" tag -m v1.0 v1.0 $C &&
	git -C "$bare" tag -m v2.0 v2.0 $D &&
	TAG1=$(git -C "$bare" rev-parse v1.0) &&
	TAG2=$(git -C "$bare" rev-parse v2.0)
'

test_expect_success "local clone" '
	rm -rf work &&
	git clone "$bare" work &&
	(
		cd work &&
		git show-ref
	) >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect<<-EOF &&
	<COMMIT-K> refs/heads/main
	<COMMIT-K> refs/remotes/origin/HEAD
	<COMMIT-K> refs/remotes/origin/main
	<COMMIT-B> refs/remotes/origin/test
	<TAG-1> refs/tags/v1.0
	<TAG-2> refs/tags/v2.0
	EOF
	test_cmp expect actual
'

test_expect_success "clone --no-local" '
	rm -rf work &&
	git clone --no-local "$bare" work &&
	(
		cd work &&
		git show-ref
	) >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect<<-EOF &&
	<COMMIT-K> refs/heads/main
	<COMMIT-K> refs/remotes/origin/HEAD
	<COMMIT-K> refs/remotes/origin/main
	<COMMIT-B> refs/remotes/origin/test
	<TAG-1> refs/tags/v1.0
	<TAG-2> refs/tags/v2.0
	EOF
	test_cmp expect actual
'

test_expect_success "clone --no-local --black-hole" '
	rm -rf work &&
	git clone --no-local --black-hole "$bare" work >out 2>&1 &&
	tail -1 out | sed -e "s/1[0-9][0-9][0-9] bytes/1xxx bytes/" >actual &&
	cat >expect<<-EOF &&
	NOTE: read total 1xxx bytes of pack data from server.
	EOF
	test_cmp expect actual
'

test_expect_success "nothing saved to disk" '
	find work/.git/objects -type f >actual &&
	cat >expect<<-EOF &&
	EOF
	test_cmp expect actual
'

test_expect_success "clone --no-local --black-hole-verify" '
	rm -rf work &&
	git clone --no-local --black-hole-verify "$bare" work
'

test_expect_success "nothing saved to disk" '
	find work/.git/objects -type f >actual &&
	cat >expect<<-EOF &&
	EOF
	test_cmp expect actual
'

test_expect_success "clone --no-local --black-hole --mirror" '
	rm -rf work &&
	git clone --no-local --black-hole --mirror "$bare" work >out 2>&1 &&
	tail -1 out | sed -e "s/1[0-9][0-9][0-9] bytes/1xxx bytes/" >actual &&
	cat >expect<<-EOF &&
	NOTE: read total 1xxx bytes of pack data from server.
	EOF
	test_cmp expect actual
'

test_expect_success "nothing saved to disk" '
	find work/objects -type f >actual &&
	cat >expect<<-EOF &&
	EOF
	test_cmp expect actual
'

test_expect_success "clone --no-local --black-hole-verify --mirror" '
	rm -rf work &&
	git clone --no-local --black-hole-verify --mirror "$bare" work
'

test_expect_success "nothing saved to disk" '
	find work/objects -type f >actual &&
	cat >expect<<-EOF &&
	EOF
	test_cmp expect actual
'

test_expect_success "normal fetch" '
	rm -rf work &&
	create_bare_repo work &&
	(
		cd work &&
		git remote add origin "../$bare" &&
		git fetch origin &&
		git show-ref
	) >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect<<-EOF &&
	<COMMIT-K> refs/remotes/origin/main
	<COMMIT-B> refs/remotes/origin/test
	<TAG-1> refs/tags/v1.0
	<TAG-2> refs/tags/v2.0
	EOF
	test_cmp expect actual
'

test_expect_success "normal fetch in bare repo" '
	rm -rf work &&
	create_bare_repo work &&
	(
		cd work &&
		git remote add --mirror origin "../$bare" &&
		git fetch origin &&
		git show-ref
	) >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect<<-EOF &&
	<COMMIT-K> refs/heads/main
	<COMMIT-B> refs/heads/test
	<TAG-1> refs/tags/v1.0
	<TAG-2> refs/tags/v2.0
	EOF
	test_cmp expect actual
'

test_expect_success "fetch --black-hole" '
	rm -rf work &&
	create_bare_repo work &&
	(
		cd work &&
		git remote add origin "../$bare" &&
		git fetch --black-hole origin 2>&1
	) >out &&
	tail -1 out | sed -e "s/1[0-9][0-9][0-9] bytes/1xxx bytes/" >actual &&
	cat >expect<<-EOF &&
	NOTE: read total 1xxx bytes of pack data from server.
	EOF
	test_cmp expect actual
'

test_expect_success "nothing saved to disk" '
	find work/objects -type f >actual &&
	cat >expect<<-EOF &&
	EOF
	test_cmp expect actual
'

test_expect_success "fetch --black-hole-verify" '
	rm -rf work &&
	create_bare_repo work &&
	(
		cd work &&
		git remote add origin "../$bare" &&
		git fetch --black-hole-verify origin
	)
'

test_expect_success "nothing saved to disk" '
	find work/objects -type f >actual &&
	cat >expect<<-EOF &&
	EOF
	test_cmp expect actual
'

test_done
