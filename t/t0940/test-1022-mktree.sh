#!/bin/sh

# Test crypto on "git-mktree"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'mktree to create new tree object' '
	(
		cat >data <<-EOF &&
			Input data for hash-object.
			EOF
		cd bare.git &&
		# create object
		oid=$(git hash-object -t blob -w ../data) &&
		git ls-tree -r master >../tree.txt &&
		cat >>../tree.txt <<-EOF &&
		100644 blob $oid	hash-object.txt
		EOF
		# create tree
		tid=$(git mktree <../tree.txt) &&
		git ls-tree -r $tid
	) | make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	100644 blob <OID>    README.txt
	100644 blob <OID>    hash-object.txt
	EOF
	test_cmp expect actual
'
