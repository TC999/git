#!/bin/sh

test_description='ls-tree pattern'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-t3100.sh

test_expect_success 'setup' '
	setup_basic_ls_tree_data
'

test_expect_success 'ls-tree pattern usage' '
	test_expect_code 129 git ls-tree --pattern HEAD &&
	test_expect_code 128 git ls-tree --pattern "" HEAD >err 2>&1 &&
	grep "Not a valid pattern, the value is empty" err
'

test_expect_success 'combine with "--object-only"' '
	cat > expect <<-EOF &&
		6da7993
	EOF

	git ls-tree --object-only --abbrev=7 --pattern "6da7993" HEAD > actual &&
	test_cmp expect actual
'

test_expect_success 'combine with "--name-only"' '
	cat > expect <<-EOF &&
		.gitmodules
		top-file.t
	EOF

	git ls-tree --name-only --pattern "\." HEAD > actual &&
	test_cmp expect actual
'

test_expect_success 'combine with "--long"' '
	cat > expect <<-EOF &&
		100644 blob 6da7993      61	.gitmodules
		100644 blob 02dad95       9	top-file.t
	EOF
	git ls-tree --long --abbrev=7 --pattern "blob" HEAD > actual &&
	test_cmp expect actual
'

test_expect_success 'combine with "--format"' '
	# Change the output format by replacing space separators with asterisks.
	format="%(objectmode)*%(objecttype)*%(objectname)%x09%(path)" &&
	pattern="100644\*blob" &&

	cat > expect <<-EOF &&
		100644*blob*6da7993	.gitmodules
		100644*blob*02dad95	top-file.t
	EOF

	git ls-tree --abbrev=7 --format "$format" --pattern "$pattern" HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'default output format (only with "--pattern" option)' '
	cat > expect <<-EOF &&
		100644 blob 6da7993ca1a3435f63c598464f77bdc6dae15aa5	.gitmodules
		100644 blob 02dad956d9274a70f7fafe45a5ffa2e123acd9a8	top-file.t
	EOF
	git ls-tree --pattern "blob" HEAD > actual &&
	test_cmp expect actual
'

test_done
