#!/bin/sh
#
# Copyright (c) 2023 Jiang Xin
#

test_description='Test edit-tree'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success "setup" '
	blob_empty=$(printf "" | git hash-object -t blob -w --stdin) &&
	blob_foo=$(printf "foo\n" | git hash-object -t blob -w --stdin) &&
	blob_bar=$(printf "bar\n" | git hash-object -t blob -w --stdin) &&
	blob_baz=$(printf "baz\n" | git hash-object -t blob -w --stdin) &&

	mkdir -p 1/12/123 &&
	printf "foo\n" >1/12/123/foo.1 &&
	printf "bar\n" >1/12/123/bar.1 &&

	mkdir -p 1/12/124 &&
	printf "baz\n" >1/12/124/baz.1 &&

	mkdir -p 2/23/234 &&
	printf "foo\n" >2/23/234/foo.2 &&
	printf "bar\n" >2/23/bar.2 &&

	touch .gitignore &&
	printf "foo\n" >FOO &&
	printf "bar\n" >BAR &&

	git add 1 2 .gitignore FOO BAR &&

	test_tick &&
	git commit -m "initial" &&
	git init --bare repo.git &&
	git remote add origin repo.git &&
	git push -u origin HEAD
'

test_expect_success "ls-tree root tree" '
	cat >actions <<-\EOF &&
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 .
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 .
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual
'

test_expect_success "ls-tree subdir" '
	cat >actions <<-\EOF &&
		# show subtree: 1
		ls-tree 1

		echo ------------------------------------------------------------

		# show subtree: 2/23
		ls-tree 2/23
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 ( ?)
		------------------------------------------------------------
		040000 tree 51028400430a306a2ec2675cbbb981a8489935ef 2/23
		040000 tree 401608e5cc4bae493696e5745c8296cc5174553b 2/23/234 ( ?)
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 2/23/bar.2
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 ( ?)
		------------------------------------------------------------
		040000 tree 569c0053e65d741e8669e75d118a051fecfe05fb27165495feec240cbc9bb587 2/23
		040000 tree 93e18a6405908c216d0f60ee275f29d6ebabc4158a6b0017719ca08729fa4f70 2/23/234 ( ?)
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 2/23/bar.2
	EOF
	test_cmp expect-${test_hash_algo} actual
'

test_expect_success "walk existing subdir" '
	cat >actions <<-\EOF &&
		walk 1/12/124
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 .
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12
		040000 tree 9d507b849df05790457926fc09963c240a512074 1/12/123 ( ?)
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124
		100644 blob 76018072e09c5d31c8c6e3113b8aa0fe625195ca 1/12/124/baz.1
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 .
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12
		040000 tree 29c70e77787996bdc0d100c6456b3f90da3f82aeb0d989d0fcb9d4e6255d7571 1/12/123 ( ?)
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124
		100644 blob 93f067803109c95715a3fa7df3d2c6364fa52a0a3f7e49f7073a9c26dea8e8c0 1/12/124/baz.1
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual
'

test_expect_success "walk non-exist tree to create placeholders" '
	cat >actions <<-\EOF &&
		# walk create place holders, but is empty
		walk 1/12/123/1234/12345

		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 .
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12
		040000 tree 9d507b849df05790457926fc09963c240a512074 1/12/123
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 1/12/123/bar.1
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 1/12/123/foo.1
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 .
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12
		040000 tree 29c70e77787996bdc0d100c6456b3f90da3f82aeb0d989d0fcb9d4e6255d7571 1/12/123
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 1/12/123/bar.1
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 1/12/123/foo.1
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual
'

test_done
