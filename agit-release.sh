#!/bin/sh

ONTO=refs/tags/v2.24.1
BRANCH=agit-master

usage() {
	cat <<-EOF
Usage: $(basename $0) [--onto <tag>] [--relese <release-branch>] <topic-branch> ...

Default values:
  - onto tag:       $ONTO
  - release branch: $BRANCH

EOF
	die "$@"
}

die() {
	if test $# -gt 0
	then
		echo >&2 "ERROR: $@"
	fi
	exit 1
}

while test $# -gt 0
do
	case $1 in
	--onto)
		shift
		ONTO=$1
		shift
		;;
	--release)
		shift
		BRANCH=$1
		shift
		;;
	-h | --help)
		shift
		usage
		;;
	*)
		break
		;;
	esac
done

BRANCH=${BRANCH#refs/heads/}

if test $# -eq 0
then
	usage "no topic branches provided"
fi

if test -z "$ONTO"
then
	usage "empty onto"
elif ! git rev-parse -q --verify "$ONTO" >/dev/null
then
	usage "fail to parse $ONTO"
fi

if test -z "$BRANCH"
then
	usage "empty branch"
fi

if git rev-parse -q --verify "refs/heads/$BRANCH" >/dev/null
then
	echo >&2 "WARNING: branch '$BRANCH' is already exist, will be overwritten"
	git checkout -q "$BRANCH" --
	git reset -q --hard "$ONTO" --
else
	git checkout -q -b "$BRANCH" "$ONTO" --
fi

if test -n "$(git status -suno)"
then
	die "worktree is not clean"
fi

while test $# -gt 0
do
	printf "rebase $1... \t"
	topic=$1
	git checkout -q "${topic}^0" --
	if test $? -ne 0
	then
		die "fail to checkout ${topic}^0 --"
	fi
	git rebase --quiet --ignore-whitespace --onto "$BRANCH" "$ONTO" HEAD
	if test $? -ne 0
	then
		die "fail to run git rebase --onto $BRANCH $ONTO HEAD"
	fi
	git update-ref "refs/heads/$BRANCH" HEAD
	if test $? -ne 0
	then
		die "fail to update-ref $BRANCH"
	fi
	printf "done\n"
	shift
done

git checkout -q "$BRANCH"
