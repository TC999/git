#!/bin/sh

# Test crypto on "git-ls-tree"

test_expect_success 'ls-tree main' '
	git -C "$COMMON_GITDIR" ls-tree -r main |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	100644 blob <OID>    README.txt
	EOF
	test_cmp expect actual
'
