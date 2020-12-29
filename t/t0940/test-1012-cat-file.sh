#!/bin/sh

# Test crypto on "git-cat-file"

test_expect_success 'cat $A' '
	git -C "$COMMON_GITDIR" cat-file -p $A |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	tree <OID>
	author A U Thor <author@example.com> 1112911993 -0700
	committer C O Mitter <committer@example.com> 1112911993 -0700
	
	Commit-A
	EOF
	test_cmp expect actual
'

test_expect_success 'cat $D' '
	git -C "$COMMON_GITDIR" cat-file -p $D |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	tree <OID>
	parent <COMMIT-C>
	author A U Thor <author@example.com> 1112912173 -0700
	committer C O Mitter <committer@example.com> 1112912173 -0700
	
	Commit-D
	EOF
	test_cmp expect actual
'

test_expect_success 'cat $E' '
	git -C "$COMMON_GITDIR" cat-file -p $E |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	tree <OID>
	parent <COMMIT-C>
	author A U Thor <author@example.com> 1112912173 -0700
	committer C O Mitter <committer@example.com> 1112912233 -0700
	
	Commit-E
	EOF
	test_cmp expect actual
'

test_expect_success 'cat $F' '
	git -C "$COMMON_GITDIR" cat-file -p $F |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	tree <OID>
	parent <COMMIT-C>
	author A U Thor <author@example.com> 1112912173 -0700
	committer C O Mitter <committer@example.com> 1112912293 -0700
	
	Commit-F
	EOF
	test_cmp expect actual
'
