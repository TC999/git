#!/bin/sh

# Test crypto on "git-archive and git-upload-archive"

test_expect_success 'archive main' '
	git -C "$COMMON_GITDIR" archive \
		--prefix=main/ -o "$(pwd)/archive.tar.gz" main &&
	tar ztf archive.tar.gz >actual &&
	cat >expect <<-EOF &&
	main/
	main/README.txt
	EOF
	test_cmp expect actual
'

test_expect_success 'remote archive for git-upload-archive testing' '
	git archive \
		--remote "$COMMON_GITDIR" \
		--prefix=main/ \
		-o remote-archive.tar.gz \
		main &&
	tar ztf remote-archive.tar.gz >actual &&
	cat >expect <<-EOF &&
	main/
	main/README.txt
	EOF
	test_cmp expect actual
'
