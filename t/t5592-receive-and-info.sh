#!/bin/sh
#
# Copyright (c) 2021 Han Xin
#

test_description='Test info commits and trees when receive pack'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

setup () {
	test_when_finished "rm -rf dest.git" &&
	git init --bare dest.git &&
	git -C dest.git config core.bigFileThreshold $1 &&
	if test -n "$2"
	then
		git -C dest.git index-pack --stdin <$2
	fi
}

check () {
	test -f $1/info/$2 &&
	test $(cat $1/info/$2 | wc -l) -eq $3
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

check_thin() {
	test_must_fail git index-pack --stdin <$1 2>stderr &&
	test_i18ngrep "unresolved deltas" stderr
}

test_expect_success 'setup' '
	test_commit --append aaaa file1 &&
	test_commit --append bbbb file2 &&
	test_commit --append cccc file3 &&
	test_commit --append dddd file4 &&
	git update-ref refs/heads/stage-1 HEAD &&
	test_commit --append eeee file5 &&
	test_commit --append ffff file6 &&
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
	check_deltas stderr -ge 2 &&
	check_thin 2.pack
'

test_expect_success 'pack with OFS_DELTA' '
	git -c pack.threads=1 pack-objects --revs --progress --thin --delta-base-offset --stdout \
		1>3.pack 2>stderr <<-\EOF &&
		^stage-1
		stage-2
		EOF
	check_deltas stderr -ge 2 &&
	check_thin 3.pack
'

test_save_receive_pack_info () {
	big_file_threshold=$1
	pack=$2
	type=$3
	sum=$4
	base=$5

	test_expect_success "================ Setup bigFileThreshold $1 ================" '
		test -n "$1"
	'

	test_expect_success "unpack-objects $pack with --info-$type" '
		setup $big_file_threshold $base &&
		git -C dest.git unpack-objects --info-$type <${pack} &&
		check dest.git/objects $type $sum
	'

	test_expect_success "unpack-objects $pack without --info-$type" '
		setup $big_file_threshold $base &&
		git -C dest.git unpack-objects <${pack} &&
		! test -f dest.git/objects/info/$type
	'

	test_expect_success "index-pack $pack with --info-$type" '
		setup $big_file_threshold $base &&
		git -C dest.git index-pack --fix-thin --info-$type --stdin <${pack} &&
		check dest.git/objects $type $sum
	'

	test_expect_success "index-pack $pack without --info-$type" '
		setup $big_file_threshold $base &&
		git -C dest.git index-pack --fix-thin --stdin <${pack} &&
		! test -f dest.git/objects/info/$type
	'
}


test_save_receive_pack_info 2 1.pack commits 4
test_save_receive_pack_info 20m 1.pack commits 4

test_save_receive_pack_info 2 1.pack trees 4
test_save_receive_pack_info 20m 1.pack trees 4

test_save_receive_pack_info 2 2.pack commits 2 1.pack
test_save_receive_pack_info 20m 2.pack commits 2 1.pack

test_save_receive_pack_info 2 2.pack trees 2 1.pack
test_save_receive_pack_info 20m 2.pack trees 2 1.pack

test_save_receive_pack_info 2 3.pack commits 2 1.pack
test_save_receive_pack_info 20m 3.pack commits 2 1.pack
test_save_receive_pack_info 2 3.pack trees 2 1.pack
test_save_receive_pack_info 20m 3.pack trees 2 1.pack

test_done
