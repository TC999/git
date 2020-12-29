#!/bin/sh

# Test crypto on "git-read-tree"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" bare.git
'

test_expect_success 'read-tree to specific file' '
	(
		cd bare.git &&
		git read-tree --index-output=new-index main &&
		test -f new-index
	)
'
