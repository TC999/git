#!/bin/bash

test_description="test export patches with common"

. ./lib/sharness.sh

test_expect_success "setup" '
init_base_repo &&
init_base_topics
'

test_expect_success "topic.txt exist, but local and remote not exist" '
test_when_finished "rm -rf workspace expect expect-*"
git clone base.git workspace &&
(
	cd workspace &&
	git switch master &&
	printf "feature4\n" >>topic.txt &&
	git add topic.txt &&
	git commit -m "add feature4 on topic.txt" &&
	test_must_fail patchwork export-patches >failed-message
) &&
cat >expect <<-EOF &&
Reminding: will get git and agit version from current path files
Reminding: Remote name not provide, will be use '"'"'origin'"'"'
the topic '"'"'feature4'"'"' does not exit in local and remote
EOF
test_cmp expect workspace/failed-message
'

test_expect_success "comment out some line on topic.txt and will skip the line" '
test_when_finished "rm -rf workspace expect expect-*"
git clone base.git workspace &&
(
	cd workspace &&
	git switch master &&
	printf "feature1\n# feature2\nfeature3\n" >topic.txt &&
	git add topic.txt &&
	git commit -m "update topic.txt" &&
	patchwork export-patches &&
	ls patches/t/ >files.txt
) &&
cat >expect-series <<-EOF &&
t/0001-feature1-update.patch
t/0002-update-feature3.patch
EOF
cat >expect-test-scripts <<-EOF &&
t0001-feature1.sh
t0003-feature3.sh
EOF
cat >expect-patches <<-EOF &&
0001-feature1-update.patch
0002-update-feature3.patch
EOF
test_cmp expect-series workspace/patches/series &&
test_cmp expect-test-scripts workspace/patches/test-scripts &&
test_cmp expect-patches workspace/files.txt
'

test_expect_success "use git and agit version as argument" '
test_when_finished "rm -rf workspace expect expect-*"
git clone base.git workspace &&
(
	cd workspace &&
	git checkout v2.36.1 &&
	# Make the new tag v2.36.2
	printf "version update" >version-update &&
	git add version-update &&
	test_tick
	git commit -m "update v2.36.1 to v2.36.2" &&
	git tag v2.36.2 &&
	# Make agit-version
	git switch topic-template &&
	git branch topic/0004-agit-version topic-template &&
	git switch topic/0004-agit-version &&
	printf "agit.dev" >agit-version &&
	git add agit-version &&
	test_tick
	git commit -m "add agit-version file" &&
	git switch master &&
	printf "agit-version\n" >>topic.txt &&
	git add topic.txt &&
	git commit -m "add agit-version" &&
	patchwork export-patches --git-version v2.36.2 --agit-version 6.6.0
	ls patches/t/ >files.txt
) &&
cat >expect-series <<-EOF &&
t/0001-feature1-update.patch
t/0002-add-feature2.patch
t/0003-update-feature3.patch
t/0004-add-agit-version-file.patch
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
0004-add-agit-version-file.patch
EOF
cat >expect-agit-version-patches <<-EOF &&
From 9592f33f1aff4283a0a2aa7d13bd5e6ee02ac542 Mon Sep 17 00:00:00 2001
From: A U Thor <author@example.com>
Date: Thu, 7 Apr 2005 15:14:13 -0700
Subject: [PATCH] add agit-version file

---
 agit-version | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 agit-version

diff --git a/agit-version b/agit-version
new file mode 100644
index 0000000..4ecb513
--- /dev/null
+++ b/agit-version
@@ -0,0 +1 @@
+6.6.0
\ No newline at end of file
-- 
patchwork
EOF
test_cmp expect-series workspace/patches/series &&
test_cmp expect-test-scripts workspace/patches/test-scripts &&
test_cmp expect-patches workspace/files.txt &&
test_cmp expect-agit-version-patches workspace/patches/t/0004-add-agit-version-file.patch
'

test_expect_success "export patches to other patch, the path not exist" '
test_when_finished "rm -rf workspace testfolder expect expect-*"
git clone base.git workspace &&
(
	cd workspace && 
	git switch master &&
	patchwork export-patches --patches ../testfolder/mypatches &&
	ls ../testfolder/mypatches/t >files.txt
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
test_cmp expect-series testfolder/mypatches/series &&
test_cmp expect-test-scripts testfolder/mypatches/test-scripts &&
test_cmp expect-patches workspace/files.txt
'

test_expect_success "export patches to other patch, the path not empty" '
test_when_finished "rm -rf workspace testfolder expect expect-*"
mkdir -p testfolder/mypatches &&
printf "testfile" >testfolder/mypatches/testfile &&
git clone base.git workspace &&
(
	cd workspace && 
	git switch master &&
	test_must_fail patchwork export-patches --patches ../testfolder/mypatches >failed-message
) &&
cat >expect <<-EOF &&
Reminding: will get git and agit version from current path files
Reminding: Remote name not provide, will be use '"'"'origin'"'"'
ERROR: the patch '"'"'../testfolder/mypatches'"'"' is not empty, please manually delete the contents
EOF
test_cmp expect workspace/failed-message
'

test_done