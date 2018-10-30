#!/bin/sh
#
# Copyright (c) 2019 Jiang Xin
#

test_description='Test git quiltexport'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

bare=bare.git

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
	shift &&
	while test $# -gt 0
	do
		name=$1 &&
		H=$(echo $name | git -C "$repo" hash-object --stdin -t blob -w)
		T=$(
			(if test -n "$parent"; then
				git -C "$repo" ls-tree $parent
			 fi; printf "100644 blob $H\t$name.txt\n") |
			git -C "$repo" mktree
		) &&
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

make_user_friendly_and_stable_output () {
	sed \
		-e "s/$(get_abbrev_oid $A)[0-9a-f]*/<COMMIT-A>/g" \
		-e "s/$(get_abbrev_oid $B)[0-9a-f]*/<COMMIT-B>/g" \
		-e "s/$(get_abbrev_oid $C)[0-9a-f]*/<COMMIT-C>/g" \
		-e "s/$(get_abbrev_oid $D)[0-9a-f]*/<COMMIT-D>/g" \
		-e "s/$(get_abbrev_oid $E)[0-9a-f]*/<COMMIT-E>/g" \
		-e "s/$(get_abbrev_oid $F)[0-9a-f]*/<COMMIT-F>/g"
}

test_expect_success setup '
	create_bare_repo "$bare" &&
	create_commits_in "$bare" A B C D E F &&
	git -C "$bare" update-ref refs/heads/test $B &&
	test_tick &&
	git -C "$bare" tag -m v1.0 v1.0 $C &&
	git -C "$bare" tag -m v2.0 v2.0 $D
'

test_expect_success "clone" '
	git clone "$bare" work
'

test_expect_success "git rev-list \$D..HEAD" '
	git -C work log --oneline $D..HEAD -- >out &&
	make_user_friendly_and_stable_output <out >actual &&
	cat >expect<<-EOF &&
	<COMMIT-F> F
	<COMMIT-E> E
	EOF
	test_cmp expect actual
'

test_expect_success "git quiltexport \$D" '
	git -C work quiltexport $D &&
	cat >expect<<-EOF &&
	t/0001-E.patch
	t/0002-F.patch
	EOF
	test_cmp expect work/patches/series
'

test_expect_success "patch files exist" '
	test -s work/patches/t/0001-E.patch &&
	test -s work/patches/t/0002-F.patch &&
	test -s work/patches/series
'

test_expect_success "git quiltexport ^\$B" '
	git -C work quiltexport --patches patches-02 ^$B &&
	cat >expect<<-EOF &&
	t/0001-C.patch
	t/0002-D.patch
	t/0003-E.patch
	t/0004-F.patch
	EOF
	test_cmp expect work/patches-02/series &&
	test -f work/patches-02/t/0001-C.patch &&
	test -f work/patches-02/t/0002-D.patch &&
	test -f work/patches-02/t/0003-E.patch &&
	test -f work/patches-02/t/0004-F.patch
'

test_expect_success "git quiltexport v2.0 ^v1.0" '
	(
		cd work &&
		git quiltexport --patches patches-03 v2.0 ^v1.0
	) &&
	cat >expect<<-EOF &&
	t/0001-D.patch
	EOF
	test_cmp expect work/patches-03/series &&
	test -f work/patches-03/t/0001-D.patch
'

test_expect_success "git quiltexport \$A..v2.0" '
	(
		cd work &&
		git quiltexport --patches patches-04 $A..v2.0
	) &&
	cat >expect<<-EOF &&
	t/0001-B.patch
	t/0002-C.patch
	t/0003-D.patch
	EOF
	test_cmp expect work/patches-04/series &&
	test -f work/patches-04/t/0001-B.patch &&
	test -f work/patches-04/t/0002-C.patch &&
	test -f work/patches-04/t/0003-D.patch
'

test_expect_success "git quiltexport --not \$1.0 --not \$v2.0" '
	(
		cd work &&
		git quiltexport --patches patches-05 -- --not $B --not $D
	) &&
	cat >expect<<-EOF &&
	t/0001-C.patch
	t/0002-D.patch
	EOF
	test_cmp expect work/patches-05/series &&
	test -f work/patches-05/t/0001-C.patch &&
	test -f work/patches-05/t/0002-D.patch
'

test_done
