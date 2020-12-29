#!/bin/sh

# Test crypto on "git-fsck"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'fsck' '
	git -C bare.git fsck
'

test_expect_success 'pack and fsck' '
	(
		cd bare.git &&
		rm objects/pack/pack-$PACK1.keep && 
		rm objects/pack/pack-$PACK2.keep && 
		git gc &&
		git fsck
	)
'
