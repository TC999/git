#!/bin/sh

# Test crypto on "git-archive and git-upload-archive"

test_expect_success 'archive master' '
	git -C "$COMMON_GITDIR" archive \
		--prefix=master/ -o "$(pwd)/archive.tar.gz" master &&
	tar ztf archive.tar.gz >actual &&
	cat >expect <<-EOF &&
	master/
	master/README.txt
	EOF
	test_cmp expect actual
'

test_expect_success 'remote archive for git-upload-archive testing' '
	git archive \
		--remote "$COMMON_GITDIR" \
		--prefix=master/ \
		-o remote-archive.tar.gz \
		master &&
	tar ztf remote-archive.tar.gz >actual &&
	cat >expect <<-EOF &&
	master/
	master/README.txt
	EOF
	test_cmp expect actual
'
