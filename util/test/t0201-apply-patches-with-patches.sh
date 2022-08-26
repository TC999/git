#!/usr/bin/bash

test_description="test export patches with --patches"

. ./lib/sharness.sh

test_expect_success "setup" '
	init_base_repo &&
	init_base_topics
'

test_expect_success "apply patches with --patches" '
	test_when_finished "rm -rf workspace tmp patches expect expect-*" &&
	mkdir patches &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout v2.36.1
	) &&
	git clone base.git tmp &&
	(
		cd tmp &&
		# Just export the test patches
		git switch master &&
		patchwork export-patches --patches ../patches &&
		patchwork apply-patches --patches ../patches --apply-to ../workspace
	) &&
	(
		cd workspace &&
		git log v2.36.1.. --format=%s >applied-commit
	) &&
	cat >expect <<-EOF &&
		update feature3
		add feature2
		feature1 update
	EOF
	test_cmp expect workspace/applied-commit
'

test_expect_success "apply patches with --patches, and patches path not exist" '
	test_when_finished "rm -rf workspace tmp patches expect expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git switch master &&
		test_must_fail patchwork apply-patches --patches ../patches --apply-to ../workspace >failed-message
	) &&
	cat >expect <<-EOF &&
		Reminding: will get git and agit version from current path files
		ERROR: the patch '"'"'../patches'"'"' not exist
	EOF
	test_cmp expect workspace/failed-message
'

test_expect_success "apply patches with --patches, the patches folder does not have series file" '
	test_when_finished "rm -rf workspace tmp patches expect expect-*" &&
	mkdir patches &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout v2.36.1
	) &&
	git clone base.git tmp &&
	(
		cd tmp &&
		# Just export the test patches
		git switch master &&
		patchwork export-patches --patches ../patches &&
		rm -rf ../patches/series &&
		test_must_fail patchwork apply-patches --patches ../patches --apply-to ../workspace >failed-message
	) &&
	cat >expect <<-EOF &&
		Reminding: will get git and agit version from current path files
		open ../patches/series: no such file or directory
	EOF
	test_cmp expect tmp/failed-message
'

test_expect_success "apply patches with --patches, and series file have garbage contents" '
	test_when_finished "rm -rf workspace tmp patches expect expect-*" &&
	mkdir patches &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout v2.36.1
	) &&
	git clone base.git tmp &&
	(
		cd tmp &&
		# Just export the test patches
		git switch master &&
		patchwork export-patches --patches ../patches &&
		cat >../patches/series <<-\EOF &&
			feature1 h01 something #abc
			feature2
			feature3
		EOF
		test_must_fail patchwork apply-patches --patches ../patches --apply-to ../workspace >failed-message
	)&&
	cat >expect <<-EOF &&
		Reminding: will get git and agit version from current path files
		series have garbage contents: something
	EOF
	test_cmp expect tmp/failed-message
'

test_expect_success "apply patches with --patches, and series file have comment" '
	test_when_finished "rm -rf workspace tmp patches expect expect-*" &&
	mkdir patches &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git checkout v2.36.1
	) &&
	git clone base.git tmp &&
	(
		cd tmp &&
		# Just export the test patches
		git switch master &&
		patchwork export-patches --number --patches ../patches &&
		cat >../patches/series <<-\EOF &&
			# this is comment
			t/0001-feature1-update.patch
			t/0002-add-feature2.patch
			t/0003-update-feature3.patch
		EOF
		patchwork apply-patches --patches ../patches --apply-to ../workspace
	)&&
	(
		cd workspace &&
		git log v2.36.1.. --format=%s >applied-commit
	) &&
	cat >expect <<-EOF &&
		update feature3
		add feature2
		feature1 update
	EOF
	test_cmp expect workspace/applied-commit
'

test_done