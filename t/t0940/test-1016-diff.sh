#!/bin/sh

# Test crypto on "git-diff"

test_expect_success 'diff v1 master' '
	git -C "$COMMON_GITDIR" diff --stat v1 master |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	 README.txt | 4 ++++
	 1 file changed, 4 insertions(+)
	EOF
	test_cmp expect actual
'
