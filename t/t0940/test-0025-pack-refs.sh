#!/bin/sh

# Test crypto on "git-pack-refs"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'has loose refs' '
	(
		cd bare.git &&
		test -f refs/heads/topic/1 &&
		test -f refs/tags/v1 &&
		test -f refs/tags/v2 &&
		test -f refs/tags/v3 &&
		test -f refs/tags/v4
	)
'

test_expect_success 'git pack-refs --all' '
	(
		cd bare.git &&
		git pack-refs --all &&
		test -f packed-refs &&
		test ! -f refs/heads/topic/1 &&
		test ! -f refs/tags/v1 &&
		test ! -f refs/tags/v2 &&
		test ! -f refs/tags/v3 &&
		test ! -f refs/tags/v4
	)
'
