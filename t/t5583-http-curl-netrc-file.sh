#!/bin/sh

test_description='test GIT_CURL_NETRC_FILE'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

setup_askpass_helper

test_expect_success 'clone auth-fetch repository with specified netrc file' '
	mkdir "$HTTPD_DOCUMENT_ROOT_PATH/repo.git" &&
	git -C "$HTTPD_DOCUMENT_ROOT_PATH/repo.git" --bare init &&
	echo "machine $HTTPD_HOST login user@host password pass@host" > git-netrc &&
	set_askpass wrong &&
	GIT_CURL_NETRC_FILE="git-netrc" git clone $HTTPD_URL/auth/smart/repo.git &&
	expect_askpass none
'

test_expect_success 'push auth-fetch repository with specified netrc file' '
	(
		git init test-push &&
		cd test-push &&
		git remote add origin $HTTPD_URL/auth/smart/repo.git && 
		test_commit first &&
		echo "machine $HTTPD_HOST login user@host password pass@host" > git-netrc &&
		set_askpass wrong &&
		GIT_CURL_NETRC_FILE="git-netrc" git push origin HEAD:test &&
		expect_askpass none
	)
'

test_done
