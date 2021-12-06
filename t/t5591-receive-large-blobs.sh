#!/bin/sh
#
# Copyright (c) 2021 Han Xin
#

test_description='Test receive large blobs when receive pack'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

setup () {
	test_when_finished "rm -rf dest.git" &&
	git init --bare dest.git &&
	git -C dest.git config core.bigFileThreshold 100
	if test -n "$1"
	then
		git -C dest.git index-pack --stdin <$1
	fi
}

check () {
	test -f $1/info/large-blobs &&
	test $(cat $1/info/large-blobs | wc -l) -eq $2
}

# usage: check_deltas <stderr_from_pack_objects> <cmp_op> <nr_deltas>
# e.g.: check_deltas stderr -gt 0
check_deltas() {
	deltas=$(perl -lne '/delta (\d+)/ and print $1' "$1") &&
	shift &&
	if ! test "$deltas" "$@"
	then
		echo >&2 "unexpected number of deltas (compared $delta $*)"
		return 1
	fi
}

test_expect_success 'setup packfile contains large blobs' '
	test_commit --append small small-blob &&
	test-tool genrandom bar 128 >big-blob &&
	test_commit --append big-one big-blob &&
	test_commit --append big-two big-blob &&
	test_commit --append big-three big-blob &&
	test_commit --append big-four big-blob &&
	git update-ref refs/heads/stage-1 HEAD &&
	test_commit --append big-five big-blob &&
	test_commit --append big-six big-blob &&
	git update-ref refs/heads/stage-2 HEAD
'

test_expect_success 'pack without delta' '
	git pack-objects --revs --progress --window=0 --stdout \
		1>1.pack 2>stderr <<-\EOF &&
		stage-1
		EOF
	check_deltas stderr = 0
'

test_expect_success 'pack with REF_DELTA' '
	git -c pack.threads=1 pack-objects --revs --progress --thin --stdout \
		1>2.pack 2>stderr <<-\EOF &&
		^stage-1
		stage-2
		EOF
	check_deltas stderr -gt 0
'

test_expect_success 'pack with OFS_DELTA' '
	git -c pack.threads=1 pack-objects --revs --progress --thin --delta-base-offset --stdout \
		1>3.pack 2>stderr <<-\EOF &&
		^stage-1
		stage-2
		EOF
	check_deltas stderr -gt 0
'

test_save_receive_pack_info () {
	pack=$1
	sum=$2
	base=$3
	test_expect_success 'unpack-objects with --info-large-blobs' '
		setup $base &&
		git -C dest.git unpack-objects --info-large-blobs <${pack} &&
		check dest.git/objects $sum
	'

	test_expect_success 'unpack-objects without --info-large-blobs' '
		setup $base &&
		git -C dest.git unpack-objects <${pack} &&
		! test -f dest.git/objects/info/large-blobs
	'

	test_expect_success 'index-pack with --info-large-blobs' '
		setup $base &&
		git -C dest.git index-pack --fix-thin --info-large-blobs --stdin <${pack} &&
		check dest.git/objects $sum
	'

	test_expect_success 'index-pack without --info-large-blobs' '
		setup $base &&
		git -C dest.git index-pack --fix-thin --stdin <${pack} &&
		! test -f dest.git/objects/info/large-blobs
	'
}

test_save_receive_pack_info 1.pack 4

test_save_receive_pack_info 2.pack 2 1.pack

test_save_receive_pack_info 3.pack 2 1.pack

test_done
