#!/bin/sh

# Test crypto on "git-show"

test_expect_success 'git show master' '
	git -C "$COMMON_GITDIR" show master |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	commit <COMMIT-F>
	Author: A U Thor <author@example.com>
	Date: Thu Apr 7 15:16:13 2005 -0700
	
	 Commit-F
	
	diff --git a/README.txt b/README.txt
	index <OID1>..<OID2> 100644
	--- a/README.txt
	+++ b/README.txt
	@@ -1,3 +1,6 @@
	 Commit-A
	 Commit-B
	 Commit-C
	+Commit-D
	+Commit-E
	+Commit-F
	EOF
	test_cmp expect actual
'

test_expect_success 'git show v1' '
	git -C "$COMMON_GITDIR" show v1 |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	tag v1
	Tagger: C O Mitter <committer@example.com>
	Date: Thu Apr 7 15:20:13 2005 -0700
	
	v1
	
	commit <COMMIT-B>
	Author: A U Thor <author@example.com>
	Date: Thu Apr 7 15:13:13 2005 -0700
	
	 Commit-B
	
	diff --git a/README.txt b/README.txt
	new file mode 100644
	index <OID1>..<OID2>
	--- /dev/null
	+++ b/README.txt
	@@ -0,0 +1,2 @@
	+Commit-A
	+Commit-B
	EOF
	test_cmp expect actual
'

test_expect_success 'git show v3' '
	git -C "$COMMON_GITDIR" show v3 |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	tag v3
	Tagger: C O Mitter <committer@example.com>
	Date: Thu Apr 7 15:22:13 2005 -0700
	
	v3
	
	commit <COMMIT-E>
	Author: A U Thor <author@example.com>
	Date: Thu Apr 7 15:16:13 2005 -0700
	
	 Commit-E
	
	diff --git a/README.txt b/README.txt
	index <OID1>..<OID2> 100644
	--- a/README.txt
	+++ b/README.txt
	@@ -1,3 +1,5 @@
	 Commit-A
	 Commit-B
	 Commit-C
	+Commit-D
	+Commit-E
	EOF
	test_cmp expect actual
'
