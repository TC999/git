#!/bin/sh

# Test crypto on "git-log"

test_expect_success 'git log --oneline master' '
	git -C "$COMMON_GITDIR" log --oneline master |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> Commit-F
	<COMMIT-C> Commit-C
	EOF
	test_cmp expect actual
'
