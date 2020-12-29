#!/bin/sh

# Test crypto on "git-gc"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'run git-init in encrypt repo' '
	git -C bare.git init --bare
'
