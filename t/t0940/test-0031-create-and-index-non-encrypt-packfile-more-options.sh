#!/bin/sh

# Create un-encrypted packs from packed repo and run tests

. $TEST_DIRECTORY/t0940/packfile-test-functions.sh

test_expect_success "setup" '
	init_git_storage_threshold
'

test_expect_success "create commits" '
	create_commits_stage_1 &&
	git repack &&
	create_commits_stage_2 &&
	git repack &&
	create_commits_stage_3 &&
	git repack
'

test_on_create_packs \
	--delta-base-offset \
	--thin \
	--include-tag \
	--delta-islands

test_expect_success "index pack1 directly" '
	git index-pack 1.pack
'

test_expect_success "index pack2 directly" '
	git index-pack 2.pack
'

test_expect_failure "cannot index pack3 directly" '
	test_must_fail git index-pack 3.pack >out 2>&1 &&
	sed -e "s/[0-9]* unresolved/<num> unresolved/" \
		<out >actual &&
	cat >expect <<-\EOF &&
	fatal: pack has <num> unresolved deltas
	EOF
	test_cmp expect actual
'

test_expect_success "create non-encrypted repo to restore packs" '
	test_create_repo restore-no-encrypted
'

test_on_restore_repo_from_packs -C restore-no-encrypted --fix-thin

test_expect_success "create encrypted repo to restore packs" '
	test_create_repo restore-encrypted &&
	init_git_storage_threshold -C restore-encrypted &&
	init_git_crypto_settings -C restore-encrypted
'

test_on_restore_repo_from_packs -C restore-encrypted --fix-thin
