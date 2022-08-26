#!/usr/bin/bash

test_description="test export patches with default"

. ./lib/sharness.sh

test_expect_success "setup" '
	init_base_repo &&
	init_base_topics
'

test_expect_success "only have master in local" '
	test_when_finished "rm -rf workspace expect-*"
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout master &&
		patchwork export-patches &&
		ls patches/t/ >files.txt
	) &&
	cat >expect-series <<-\EOF &&
		t/0001-feature1-update.patch
		t/0002-add-feature2.patch
		t/0003-update-feature3.patch
	EOF
	cat >expect-test-scripts <<-EOF &&
		t0001-feature1.sh
		t0002-feature2.sh
		t0003-feature3.sh
	EOF
	cat >expect-patches <<-\EOF &&
		0001-feature1-update.patch
		0002-add-feature2.patch
		0003-update-feature3.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "local have master, feature1 and feature3" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout master &&
		git switch topic/0001-feature1 &&
		git switch topic/0002-feature2 &&
		git switch master &&
		patchwork export-patches &&
		ls patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/0001-feature1-update.patch
		t/0002-add-feature2.patch
		t/0003-update-feature3.patch
	EOF
	cat >expect-test-scripts <<-EOF &&
		t0001-feature1.sh
		t0002-feature2.sh
		t0003-feature3.sh
	EOF
	cat >expect-patches <<-EOF &&
		0001-feature1-update.patch
		0002-add-feature2.patch
		0003-update-feature3.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "local have master, feature1 and feature3, but feature1 inconsistent" '
	test_when_finished "rm -rf workspace expect-*" &&
	test_when_finished "rm -rf expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout master &&
		git switch topic/0001-feature1 &&
		git commit --amend --no-edit &&
		git switch topic/0002-feature2 &&
		git switch master &&
		test_must_fail patchwork export-patches >failed-message
	) &&
	cat >expect <<-EOF &&
		Reminding: will get git and agit version from current path files
		Reminding: Remote name not provide, will be use '"'"'origin'"'"'
		the topic '"'"'feature1'"'"' local and remote are inconsistent, plese use '"'"'--use-local'"'"' or '"'"'--use-remote'"'"'
	EOF
	test_cmp expect workspace/failed-message
'

test_done