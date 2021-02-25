#!/bin/sh

# Create un-encrypted packs and run tests

. $TEST_DIRECTORY/t0940/packfile-test-functions.sh

test_expect_success "setup" '
	init_git_storage_threshold
'

test_expect_success "create commits" '
	create_commits_stage_1 &&
	create_commits_stage_2 &&
	create_commits_stage_3
'

test_on_create_packs

test_expect_success "index pack1 directly" '
	git index-pack 1.pack
'

test_expect_success "index pack2 directly" '
	git index-pack 2.pack
'

test_expect_success "index pack3 directly" '
	git index-pack 3.pack
'

test_expect_success "create non-encrypted repo to restore packs" '
	test_create_repo restore-no-encrypted
'

test_on_restore_repo_from_packs -C restore-no-encrypted

test_expect_success "create encrypted repo to restore packs" '
	test_create_repo restore-encrypted &&
	init_git_storage_threshold -C restore-encrypted &&
	init_git_crypto_settings -C restore-encrypted
'

test_on_restore_repo_from_packs -C restore-encrypted
