#!/bin/sh

# Test crypto on "git-count-objects"

test_expect_success 'count-objects' '
	git -C "$COMMON_GITDIR" count-objects >actual &&
	grep -w "19 objects" actual
'
