#!/bin/sh

# Test crypto on "git-multi-pack-index"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'multi-pack-index write' '
	(
		cd bare.git &&
		git multi-pack-index write &&
		test -f objects/pack/multi-pack-index
	)
'

test_expect_success 'multi-pack-index verify' '
	(
		cd bare.git &&
		git multi-pack-index verify
	)
'
