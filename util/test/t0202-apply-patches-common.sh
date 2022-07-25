#!/usr/bin/bash

test_description="test apply patches with common test"

. ./lib/sharness.sh

test_expect_success "setup" '
init_base_repo &&
init_base_topics
'

test_expect_success "provide git and agit version while apply patches" '
test_when_finished "rm -rf workspace tmp expect expect-*"
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
	patchwork export-patches --patches ../patches
) &&
# Current path does not have GIT-VERSION and PATCH-VERSION
patchwork --git-version v2.36.1 --agit-version 6.5.8 apply-patches --apply-to workspace &&
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

test_expect_success "applied repo worktree not clean --- add file" '
test_when_finished "rm -rf workspace tmp expect expect-*"
git clone base.git workspace &&
(
	cd workspace &&
	git checkout v2.36.1 &&
	printf "not clean worktree" >bad-file &&
	git add bad-file
) &&
git clone base.git tmp &&
(
	cd tmp &&
	# Just export the test patches
	git switch master &&
	patchwork export-patches &&
	test_must_fail patchwork apply-patches --apply-to ../workspace >failed-message
) &&
cat >expect <<-EOF &&
Reminding: will get git and agit version from current path files
the repo index not clean
EOF
test_cmp expect tmp/failed-message
'

test_expect_success "applied repo worktree not clean --- update file" '
test_when_finished "rm -rf workspace tmp expect expect-*"
git clone base.git workspace &&
(
	cd workspace &&
	git checkout v2.36.1 &&
	printf "not clean worktree" >bad-file &&
	git add bad-file &&
	test_tick &&
	git commit -m "add bad-file" &&
	printf "Let us update it again" >bad-file
) &&
git clone base.git tmp &&
(
	cd tmp &&
	# Just export the test patches
	git switch master &&
	patchwork export-patches &&
	test_must_fail patchwork apply-patches --apply-to ../workspace >failed-message
) &&
cat >expect <<-EOF &&
Reminding: will get git and agit version from current path files
the repo index not clean
EOF
test_cmp expect tmp/failed-message
'

test_done