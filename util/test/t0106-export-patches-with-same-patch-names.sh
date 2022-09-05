#!/usr/bin/bash 

test_description="test export patches have same patch names"

. ./lib/sharness.sh

test_expect_success "setup" '
	init_base_repo &&
	init_base_topics
'

test_expect_success "have the same commit message features in local" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git switch master &&
		git checkout topic/0001-feature1 &&
		printf "new_file" >new_file_same &&
		git add new_file_same &&
		test_tick &&
		git commit -m "feature add new file" &&
		git checkout topic/0002-feature2 &&
		printf "new_file" >new_file_same &&
		git add new_file_same &&
		test_tick &&
		git commit -m "feature add new file" &&
		git checkout topic/0003-feature3 &&
		printf "new_file" >new_file_same &&
		git add new_file_same &&
		test_tick &&
		git commit -m "feature add new file" &&
		git checkout master &&
		patchwork export-patches --use-local &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/feature-add-new-file.patch
		t/add-feature2.patch
		t/feature-add-new-file_1.patch
		t/update-feature3.patch
		t/feature-add-new-file_2.patch
	EOF
	cat >expect-test-scripts <<-EOF &&
		t0001-feature1.sh
		t0002-feature2.sh
		t0003-feature3.sh
	EOF
	cat >expect-patches <<-EOF &&
		feature1-update.patch
		feature-add-new-file.patch
		add-feature2.patch
		feature-add-new-file_1.patch
		update-feature3.patch
		feature-add-new-file_2.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_done