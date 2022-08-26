#!/bin/bash

test_description="test export patches with topic depend"

. ./lib/sharness.sh

test_expect_success "setup" '
	init_base_repo &&
	init_base_topics &&
	git clone base.git tmp &&
	(
		cd tmp
		# Feature 4 depends on Feature2 &&
		git branch topic/0004-feature4 origin/topic/0002-feature2 &&
		git switch topic/0004-feature4 &&
		printf "this is feature4" >feature4.txt &&
		git add feature4.txt &&
		test_tick &&
		git commit -m "add feature4" &&
		git push origin topic/0004-feature4 &&
		# Feature 5 depends on Feature3 &&
		git branch topic/0005-feature5 origin/topic/0003-feature3 &&
		git switch topic/0005-feature5 &&
		printf "this is feature5" >feature5.txt &&
		git add feature5.txt &&
		test_tick &&
		git commit -m "add feature5" &&
		git push origin topic/0005-feature5
	) && 
	rm -rf tmp
'

test_expect_success "have depends on, and successfully" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git switch master &&
		cat >topic.txt <<-\EOF &&
			feature1
			feature2
			feature3
			feature4: feature2
			feature5: feature3
		EOF
		git add topic.txt &&
		test_tick &&
		git commit -m "update topic.txt with feature4 and feature5" &&
		patchwork export-patches &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/add-feature2.patch
		t/update-feature3.patch
		t/add-feature4.patch
		t/add-feature5.patch
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
		add-feature4.patch
		add-feature5.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "have depends on, feature4 is wrong order" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git switch master &&
		cat >topic.txt <<-\EOF &&
			feature1
			feature4:  feature2
			feature2
			feature3
			feature5:feature3
		EOF
		git add topic.txt &&
		test_tick &&
		git commit -m "update topic.txt with feature4 and feature5" &&
		patchwork export-patches &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/add-feature2.patch
		t/update-feature3.patch
		t/add-feature5.patch
		t/add-feature4.patch
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
		add-feature5.patch
		add-feature4.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "have depends on, feature4 is wrong order, and feature5 precedes feature4" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git switch master &&
		cat >topic.txt <<-\EOF &&
			feature1
			feature5: feature3
			feature4: feature2
			feature2
			feature3
		EOF
		git add topic.txt &&
		test_tick &&
		git commit -m "update topic.txt with feature4 and feature5" &&
		patchwork export-patches &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/add-feature2.patch
		t/update-feature3.patch
		t/add-feature4.patch
		t/add-feature5.patch
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
		add-feature4.patch
		add-feature5.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "have depends on, feature4 is wrong order, and feature5(will depends on feature4) precedes feature4" '
	test_when_finished "rm -rf workspace expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git switch master &&
		cat >topic.txt <<-\EOF &&
			feature1
			feature5: feature4
			feature4: feature2
			feature2
			feature3
		EOF
		git add topic.txt &&
		test_tick &&
		git commit -m "update topic.txt with feature4 and feature5" &&
		git switch topic/0005-feature5 &&
		git reset --hard origin/topic/0004-feature4 &&
		printf "feature5 will depends on feature4"> feature5.log &&
		git add feature5.log &&
		test_tick &&
		git commit -m "feature5 depends on feature4" &&
		git switch master &&
		patchwork export-patches --use-local &&
		ls -tr patches/t/ >files.txt
	) &&
	cat >expect-series <<-EOF &&
		t/feature1-update.patch
		t/add-feature2.patch
		t/update-feature3.patch
		t/add-feature4.patch
		t/feature5-depends-on-feature4.patch
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
		add-feature4.patch
		feature5-depends-on-feature4.patch
	EOF
	test_cmp expect-series workspace/patches/series &&
	test_cmp expect-test-scripts workspace/patches/test-scripts &&
	test_cmp expect-patches workspace/files.txt
'

test_expect_success "feature4 depends on feature2 but not rebase" '
	test_when_finished "rm -rf workspace expect expect-*" &&
	git clone base.git workspace &&
	(
		cd workspace &&
		git switch master &&
		cat >topic.txt <<-\EOF &&
			feature1
			feature2
			feature3
			feature4: feature2
			feature5: feature3
		EOF
		git add topic.txt &&
		test_tick &&
		git commit -m "update topic.txt with feature4 and feature5" &&
		git checkout topic/0004-feature4 &&
		git reset --hard origin/topic-template &&
		printf "not rebase feature2" >feature4.txt &&
		git add feature4.txt &&
		test_tick &&
		git commit -m "add feature4" &&
		git switch master &&
		test_must_fail patchwork export-patches --use-local >failed_message
	) &&
	cat >expect <<-EOF &&
		Reminding: will get git and agit version from current path files
		Reminding: Remote name not provide, will be use '"'"'origin'"'"'
		the branch topic/0004-feature4 not rebase to origin/topic/0002-feature2

	EOF
	test_cmp expect workspace/failed_message
'

test_done
