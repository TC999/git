#!/bin/sh

# Test crypto on "git-format-patch"

test_expect_success 'format-patch' '
	git -C "$COMMON_GITDIR" format-patch -o "$(pwd)" master~ &&
	head -8 0001-Commit-F.patch |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	From <COMMIT-F> Mon Sep 17 00:00:00 2001
	From: A U Thor <author@example.com>
	Date: Thu, 7 Apr 2005 15:16:13 -0700
	Subject: [PATCH] Commit-F

	---
	 README.txt | 3 +++
	 1 file changed, 3 insertions(+)
	EOF
	test_cmp expect actual
'
