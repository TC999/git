#!/bin/bash

test_description="test export patches with --use-remote"

. ./lib/sharness.sh

test_expect_success "setup" '
	init_base_repo &&
	init_base_topics
'

test_expect_success "only have master in local, --use-remote" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout master &&
		patchwork export-patches --use-remote &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/add-feature2.patch
		t/update-feature3.patch
	EOF
	cat >expect-test-scripts <<-EOF &&
		t0001-feature1.sh
		t0002-feature2.sh
		t0003-feature3.sh
	EOF
	cat >expect-patches <<-EOF &&
		feature1-update.patch
		add-feature2.patch
		update-feature3.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "local have master, feature1 and feature3, use --use-remote" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout master &&
		git switch topic/0001-feature1 &&
		git switch topic/0002-feature2 &&
		git switch master &&
		patchwork export-patches --use-remote &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/add-feature2.patch
		t/update-feature3.patch
	EOF
	cat >expect-test-scripts <<-EOF &&
		t0001-feature1.sh
		t0002-feature2.sh
		t0003-feature3.sh
	EOF
	cat >expect-patches <<-EOF &&
		feature1-update.patch
		add-feature2.patch
		update-feature3.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "local have master, feature1 and feature3, but feature1 inconsistent, --use-remote" '
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
		patchwork export-patches --use-remote &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/add-feature2.patch
		t/update-feature3.patch
	EOF
	cat >expect-test-scripts <<-EOF &&
		t0001-feature1.sh
		t0002-feature2.sh
		t0003-feature3.sh
	EOF
	cat >expect-patches <<-EOF &&
		feature1-update.patch
		add-feature2.patch
		update-feature3.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_done