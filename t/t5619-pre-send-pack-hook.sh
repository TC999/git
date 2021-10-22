#!/bin/bash

test_description='Testing pre-send-pack-hook'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success "setup upstream" '
	rm -rf upstream.git &&
	rm -rf workbench &&
	git init --bare upstream.git &&
	(
		cd upstream.git &&
		git config uploadpack.allowAnySHA1InWant true &&
		git config uploadpack.allowFilter true
	) &&
	git init workbench &&
	(
		cd workbench &&
		dd if=/dev/urandom of="file" bs=1024 count=1024 &&
		git add file &&
		git commit -m "add file" &&
		git remote add origin ../upstream.git &&
		git push origin main
	) &&
	write_script upstream.git/hooks/pre-send-pack <<-\EOF
		echo "repo too large"
	EOF
'

test_expect_success 'clone repo received message' '
	test_when_finished "rm -fr dst" &&
	git clone --progress --no-local upstream.git dst 2>output &&
	grep "repo too large" output >actual &&
	test_line_count = 1 actual
'

test_expect_success 'hook exit non zero' '
	write_script upstream.git/hooks/pre-send-pack <<-\EOF &&
		#!/bin/sh

		exit 1
	EOF
	test_when_finished "rm -fr dst" &&
	git clone --no-local upstream.git dst &&
	test -f dst/file
'

test_expect_success 'read error message from hook' '
	write_script upstream.git/hooks/pre-send-pack <<-\EOF &&
		#!/bin/sh

		echo "error from hook" 1>&2
	EOF
	test_when_finished "rm -fr dst" &&
	git clone --progress --no-local upstream.git dst 2>output &&
	cat output | grep "error from hook" >actual &&
	test_line_count = 1 actual
'

test_done
