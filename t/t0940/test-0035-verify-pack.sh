#!/bin/sh

# Test crypto on "git-verify-pack"

test_expect_success 'git verify-pack PACK1' '
	git -C "$COMMON_GITDIR" verify-pack objects/pack/pack-$PACK1.idx
'

test_expect_success 'git verify-pack PACK2' '
	git -C "$COMMON_GITDIR" verify-pack objects/pack/pack-$PACK2.idx
'
