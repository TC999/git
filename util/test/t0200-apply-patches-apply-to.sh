#!/usr/bin/bash

test_description="test apply patches with --apply-to"

. ./lib/sharness.sh

test_expect_success "setup" '
init_base_repo &&
init_base_topics
'

test_expect_success "apply patches with --apply-to" '
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
	patchwork export-patches &&
	patchwork apply-patches --apply-to ../workspace
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

test_expect_success "apply patches with --apply-to, but apply to is not exist" '
test_when_finished "rm -rf workspace tmp expect expect-*"
git clone base.git tmp &&
(
	cd tmp &&
	# Just export the test patches
	git switch master &&
	patchwork export-patches &&
	test_must_fail patchwork apply-patches --apply-to ../workspace >error-message
) &&
cat >expect <<-EOF &&
Reminding: will get git and agit version from current path files
the path '"'"'../workspace'"'"' is not a git repo
EOF
test_cmp expect tmp/error-message
'

test_done