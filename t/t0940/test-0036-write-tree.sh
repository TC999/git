#!/bin/sh

# Test crypto on "git-write-tree"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'create blob' '
	cat >bare.git/_data <<-EOF &&
	Input data for hash-object.
	EOF
	oid=$(git -C bare.git hash-object -t blob -w _data)
'

test_expect_success 'create tree' '
	cat >bare.git/_tree <<-EOF &&
	100644 blob $oid	data.txt
	EOF
	tid1=$(git -C bare.git mktree <bare.git/_tree) &&
	git -C bare.git ls-tree -r $tid1 >actual &&
	cat >expect <<-EOF &&
	100644 blob $oid	data.txt
	EOF
	test_cmp expect actual
'

# read tree to index
test_expect_success 'read-tree into subdir of index' '
	git -C bare.git read-tree -i --index-output=_index \
		--prefix="src/" $tid1
'

# create tree from index
test_expect_success 'write-tree of "src/data.txt"' '
	tid2=$(GIT_INDEX_FILE=_index git -C bare.git write-tree) &&
	git -C bare.git ls-tree -r $tid2 >actual &&
	cat >expect <<-EOF &&
	100644 blob $oid	src/data.txt
	EOF
	test_cmp expect actual
'

# merge tid2 and master to index
test_expect_success 'merge two trees' '
	empty_tree=4b825dc642cb6eb9a060e54bf8d69288fbee4904 &&
	git -C bare.git read-tree -i -m --index-output=_index \
		$empty_tree $tid2 master
'

# create tree of merge result
test_expect_success 'create tree of merged result ' '
	merged=$(GIT_INDEX_FILE=_index git -C bare.git write-tree) &&
	git -C bare.git ls-tree -r $merged |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	100644 blob <OID>    README.txt
	100644 blob <OID>    src/data.txt
	EOF
	test_cmp expect actual
'
