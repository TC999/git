#!/bin/sh

# Test crypto on "git-gc"

test_expect_success 'setup' '
	cp -R "$COMMON_GITDIR" bare.git
'

test_expect_success 'run git-init in encrypt repo' '
	git -C bare.git \
		-c init.defaultBranch="${GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME-master}" \
		init --bare
'
