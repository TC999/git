#!/bin/sh
#
# Copyright (c) 2021 Han Xin
#

test_description='Test unpack-objects when receive pack'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

prepare_dest () {
	test_when_finished "rm -rf dest.git" &&
	git init --bare dest.git &&
	git -C dest.git config core.bigFileThreshold $1
}

test_expect_success "setup repo with big blobs (1.5 MB)" '
	test-tool genrandom foo 1500000 >big-blob &&
	test_commit --append foo big-blob &&
	test-tool genrandom bar 1500000 >big-blob &&
	test_commit --append bar big-blob &&
	(
		cd .git &&
		find objects/?? -type f | sort
	) >expect &&
	PACK=$(echo main | git pack-objects --revs test)
'

test_expect_success 'setup env: GIT_ALLOC_LIMIT to 1MB' '
	GIT_ALLOC_LIMIT=1m &&
	export GIT_ALLOC_LIMIT
'

test_expect_success 'fail to unpack-objects: cannot allocate' '
	prepare_dest 2m &&
	test_must_fail git -C dest.git unpack-objects <test-$PACK.pack 2>err &&
	grep "fatal: attempting to allocate" err &&
	(
		cd dest.git &&
		find objects/?? -type f | sort
	) >actual &&
	test_file_not_empty actual &&
	! test_cmp expect actual
'

test_expect_success 'unpack big object in stream' '
	prepare_dest 1m &&
	mkdir -p dest.git/objects/05 &&
	git -C dest.git unpack-objects <test-$PACK.pack &&
	git -C dest.git fsck &&
	(
		cd dest.git &&
		find objects/?? -type f | sort
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'unpack big object in stream with existing oids' '
	prepare_dest 1m &&
	git -C dest.git index-pack --stdin <test-$PACK.pack &&
	(
		cd dest.git &&
		find objects/?? -type f | sort
	) >actual &&
	test_must_be_empty actual &&
	git -C dest.git unpack-objects <test-$PACK.pack &&
	git -C dest.git fsck &&
	(
		cd dest.git &&
		find objects/?? -type f | sort
	) >actual &&
	test_must_be_empty actual
'

test_expect_success 'unpack-objects dry-run' '
	prepare_dest 1m &&
	git -C dest.git unpack-objects -n <test-$PACK.pack &&
	(
		cd dest.git &&
		find objects/ -type f
	) >actual &&
	test_must_be_empty actual
'

test_done
