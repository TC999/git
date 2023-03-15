#!/bin/sh
#
# Copyright (c) 2023 Jiang Xin
#

test_description='Test edit-tree'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success "setup" '
	blob_missing=$(printf "missing\n" | git hash-object -t blob --stdin) &&
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
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
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
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect changes

'

test_expect_success "walk existing subdir" '
	cat >actions <<-\EOF &&
		walk 1/12/124
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
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
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect changes
'

test_expect_success "walk non-exist tree to create placeholders" '
	cat >actions <<-\EOF &&
		# walk create place holders, but is empty
		walk 1/12/123/1234/12345

		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
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
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect changes

'

test_expect_success "rm file" '
	cat >actions <<-\EOF &&
		rm 1/12/123/foo.1
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual 1>result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 (! )
		040000 tree 9d507b849df05790457926fc09963c240a512074 1/12/123 (! )
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 1/12/123/bar.1
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 (! )
		040000 tree 29c70e77787996bdc0d100c6456b3f90da3f82aeb0d989d0fcb9d4e6255d7571 1/12/123 (! )
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 1/12/123/bar.1
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		D	1/12/123/foo.1
	EOF
	test_cmp expect changes
'

test_expect_success "rm: fail to remove non-exist file" '
	cat >actions <<-\EOF &&
		rm 1/12/123/missing
		ls-tree
	EOF
	test_must_fail git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect <<-\EOF &&
		error: rm: 1/12/123/missing: no such file or directory
	EOF
	test_cmp expect actual
'

test_expect_success "rm non-exist file by force" '
	cat >actions <<-\EOF &&
		rm -f 1/12/123/missing
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 (! )
		040000 tree 9d507b849df05790457926fc09963c240a512074 1/12/123 (! )
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 1/12/123/bar.1
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 1/12/123/foo.1
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 (! )
		040000 tree 29c70e77787996bdc0d100c6456b3f90da3f82aeb0d989d0fcb9d4e6255d7571 1/12/123 (! )
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 1/12/123/bar.1
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 1/12/123/foo.1
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect changes

'

test_expect_success "rm non-exist file in non-exist dir by force" '
	cat >actions <<-\EOF &&
		rm -f 3/34/345/missing
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect changes
'

test_expect_success "rm subdir" '
	cat >actions <<-\EOF &&
		rm 1/12/123
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 (! )
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 (! )
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		D	1/12/123/bar.1
		D	1/12/123/foo.1
	EOF
	test_cmp expect changes
'

test_expect_success "add file in root tree" '
	cat >actions <<-EOF &&
		add 10755 $blob_foo foo.new
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
		010755 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 foo.new
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
		010755 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 foo.new
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		A	foo.new
	EOF
	test_cmp expect changes
'

test_expect_success "add file in sub tree" '
	cat >actions <<-EOF &&
		add 10755 $blob_baz 1/12/123/baz.new
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 (! )
		040000 tree 9d507b849df05790457926fc09963c240a512074 1/12/123 (! )
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 1/12/123/bar.1
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 1/12/123/foo.1
		010755 blob 76018072e09c5d31c8c6e3113b8aa0fe625195ca 1/12/123/baz.new
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 (! )
		040000 tree 29c70e77787996bdc0d100c6456b3f90da3f82aeb0d989d0fcb9d4e6255d7571 1/12/123 (! )
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 1/12/123/bar.1
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 1/12/123/foo.1
		010755 blob 93f067803109c95715a3fa7df3d2c6364fa52a0a3f7e49f7073a9c26dea8e8c0 1/12/123/baz.new
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		A	1/12/123/baz.new
	EOF
	test_cmp expect changes
'

test_expect_success "add duplicate file: show warning" '
	cat >actions <<-EOF &&
		add 100644 $blob_foo FOO
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		warning: already exist, ignored: FOO
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		warning: already exist, ignored: FOO
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect changes
'

test_expect_success "add duplicate file: show error for different mode" '
	cat >actions <<-EOF &&
		add 100755 $blob_foo FOO
		ls-tree
	EOF
	test_must_fail git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect <<-\EOF &&
		error: found a conflict entry with different mode or oid, please use replace command for it: FOO
	EOF
	test_cmp expect actual
'

test_expect_success "add duplicate file: force to replace" '
	cat >actions <<-EOF &&
		add -f 100755 $blob_bar FOO
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100755 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100755 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		M	FOO
	EOF
	test_cmp expect changes
'

test_expect_success "add duplicate tree: show warning" '
	oid_tree=$(git -C repo.git rev-parse "HEAD:1/12") &&
	cat >actions <<-EOF &&
		add 040000 $oid_tree 1/12
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		warning: already exist, ignored: 1/12
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		warning: already exist, ignored: 1/12
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
	EOF
	test_cmp expect changes
'

test_expect_success "add duplicate tree: show error for different OID" '
	oid_tree=$(git -C repo.git rev-parse "HEAD:2") &&
	cat >actions <<-EOF &&
		add 040000 $oid_tree 1/12
		ls-tree
	EOF
	test_must_fail git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect <<-\EOF &&
		error: found a conflict tree with different oid, please use replace command for it: 1/12
	EOF
	test_cmp expect actual
'

test_expect_success "add duplicate tree: force to overwrite a tree with different OID" '
	oid_tree=$(git -C repo.git rev-parse "HEAD:2") &&
	cat >actions <<-EOF &&
		add -f 040000 $oid_tree 1/12
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 1/12 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 1/12 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		D	1/12/123/bar.1
		D	1/12/123/foo.1
		D	1/12/124/baz.1
		A	1/12/23/234/foo.2
		A	1/12/23/bar.2
	EOF
	test_cmp expect changes
'

test_expect_success "add a file but the object is missing" '
	cat >actions <<-EOF &&
		add 100755 $blob_missing 1/MISSING
		ls-tree
	EOF
	test_must_fail git -C repo.git edit-tree -f ../actions HEAD 2>out &&
	sed -e "s/${_x35}[0-9a-f]*/OID/" <out >actual &&
	cat >expect <<-\EOF &&
		fatal: object OID is missing for path: 1/MISSING
	EOF
	test_cmp expect actual
'

test_expect_success "add a missing commit as submodule is OK" '
	cat >actions <<-EOF &&
		add 160000 $blob_missing 1/submodule
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 ( ?)
		160000 commit 33e45d56f88993aae6a0198013efa80716fd8919 1/submodule
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 ( ?)
		160000 commit ca4af469ee1c914d388902346b86732b4cdc6b3ebfcfc52cfaa89c6e9fb37642 1/submodule
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		A	1/submodule
	EOF
	test_cmp expect changes

'

test_expect_success "fatal: add a blob as a tree" '
	cat >actions <<-EOF &&
		add 040000 $blob_foo 1/BAD-TREE
	EOF
	test_must_fail git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect <<-\EOF &&
		fatal: unmatched types (actual: blob, want: tree)
	EOF
	test_cmp expect actual
'

test_expect_success "fatal add a tree object as a file" '
	oid_tree=$(git -C repo.git rev-parse "HEAD^{tree}") &&
	cat >actions <<-EOF &&
		add 100644 $oid_tree 1/BAD-FILE
	EOF
	test_must_fail git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect <<-\EOF &&
		fatal: unmatched types (actual: tree, want: blob)
	EOF
	test_cmp expect actual
'

test_expect_success "add file into a non-exist dir" '
	cat >actions <<-EOF &&
		add 10644 $blob_foo 3/34/345/foo.new
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		040000 tree                                          3 (!?)
		040000 tree                                          3/34 (!?)
		040000 tree                                          3/34/345 (!?)
		010644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 3/34/345/foo.new
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		040000 tree                                                                  3 (!?)
		040000 tree                                                                  3/34 (!?)
		040000 tree                                                                  3/34/345 (!?)
		010644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 3/34/345/foo.new
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		A	3/34/345/foo.new
	EOF
	test_cmp expect changes
'

test_expect_success "add tree into a non-exist parent dir" '
	blob_tree_2=$(git -C repo.git ls-tree HEAD -- 2 | awk "{print \$3}") &&
	cat >actions <<-EOF &&
		add-tree $blob_tree_2 3/34
		ls-tree
		echo
		commit
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		040000 tree                                          3 (!?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 3/34 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO

		040000 tree ac64a5af1fea1f6a9520664e552d4b0c1bdae98a .
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		040000 tree ef63b6ed28d2b88c78e24f315470d958da25103c 3
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 3/34 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		040000 tree                                                                  3 (!?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 3/34 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO

		040000 tree 274bbcb10c03d6ea1f90ce57d42eb65d10d982069e2699c7985c66ec646a0187 .
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		040000 tree ecf62b637449c765a9cc9990c78cddcbaa37eb97a38ef58fb2ce6cf299d6f7cf 3
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 3/34 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		A	3/34/23/234/foo.2
		A	3/34/23/bar.2
	EOF
	test_cmp expect changes
'

test_expect_success "replace file mode" '
	cat >actions <<-EOF &&
		replace 100755 $blob_foo 1/12/123/foo.1
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 (! )
		040000 tree 9d507b849df05790457926fc09963c240a512074 1/12/123 (! )
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 1/12/123/bar.1
		100755 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 1/12/123/foo.1
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 (! )
		040000 tree 29c70e77787996bdc0d100c6456b3f90da3f82aeb0d989d0fcb9d4e6255d7571 1/12/123 (! )
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 1/12/123/bar.1
		100755 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 1/12/123/foo.1
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		M	1/12/123/foo.1
	EOF
	test_cmp expect changes

'

test_expect_success "replace blob object" '
	cat >actions <<-EOF &&
		replace 100644 $blob_empty FOO
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		M	FOO
	EOF
	test_cmp expect changes
'

test_expect_success "replace tree" '
	blob_tree_2=$(git ls-tree HEAD -- 2 | awk "{print \$3}") &&
	cat >actions <<-EOF &&
		replace 040000 $blob_tree_2 1/12/123
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 (! )
		040000 tree 9a54ea19d8702278325e3ae5f571df7d9e27c14d 1/12/124 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 1/12/123 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 (! )
		040000 tree 1a8e14acdd70eb904488fcbd56e8f4c21880acc1dd6dd3c85ff0ed09939ab8e5 1/12/124 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 1/12/123 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		A	1/12/123/23/234/foo.2
		A	1/12/123/23/bar.2
		D	1/12/123/bar.1
		D	1/12/123/foo.1
	EOF
	test_cmp expect changes
'

test_expect_success "fail to replace a missing object" '
	cat >actions <<-EOF &&
		replace 100644 $blob_empty 1/FOO
		ls-tree
	EOF
	test_must_fail git -C repo.git edit-tree -f ../actions HEAD 2>actual &&
	cat >expect <<-\EOF &&
		error: rm: 1/FOO: no such file or directory
	EOF
	test_cmp expect actual
'

test_expect_success "replace a missing object, will add one" '
	cat >actions <<-EOF &&
		replace -f 100644 $blob_empty 1/FOO
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 1/FOO
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 1/FOO
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		A	1/FOO
	EOF
	test_cmp expect changes
'

test_expect_success "commit several times" '
	cat >actions <<-EOF &&
		add 10644 $blob_foo 3/34/foo.new
		add 10755 $blob_bar 4/45/bar.new
		echo ===== add two blobs =====
		ls-tree
		echo
		commit
		echo ===== commit: add two blobs =====
		ls-tree
		echo
		rm 1/12/123/foo.1
		rm 1/12/124/baz.1
		echo ===== rm two blobs =====
		ls-tree
		echo
		commit
		echo ===== commit: rm two blobs =====
		ls-tree
	EOF
	git -C repo.git edit-tree -f ../actions HEAD 2>actual >result &&
	cat >expect-sha1 <<-\EOF &&
		===== add two blobs =====
		040000 tree 773cba916aa76d29e63383bed5ae7d8bfd0c6093 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		040000 tree                                          3 (!?)
		040000 tree                                          3/34 (!?)
		010644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 3/34/foo.new
		040000 tree                                          4 (!?)
		040000 tree                                          4/45 (!?)
		010755 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 4/45/bar.new
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO

		===== commit: add two blobs =====
		040000 tree 62ef2586620dd31ff0af5fd99db21e069720c5d6 .
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 ( ?)
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		040000 tree 82e30a19b4f6c039b11f10e004f14c9d7a06bb10 3
		040000 tree 8af25e4c88ad055524fa0d456d4ea8ef2177857b 3/34
		010644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 3/34/foo.new
		040000 tree f9af4d60143860a6da76711a24a8a7637abc7bfd 4
		040000 tree 126a0ef9554dbc48cd9c571ca7542e60ee5c72b3 4/45
		010755 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 4/45/bar.new
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO

		===== rm two blobs =====
		040000 tree 62ef2586620dd31ff0af5fd99db21e069720c5d6 . (! )
		040000 tree 74531642af64742290efdc9b7674b50d85dfe64e 1 (! )
		040000 tree d9fbd0a8c7f29cd5643c6a8c8fe6927ae5ba8531 1/12 (! )
		040000 tree 9d507b849df05790457926fc09963c240a512074 1/12/123 (! )
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 1/12/123/bar.1
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		040000 tree 82e30a19b4f6c039b11f10e004f14c9d7a06bb10 3
		040000 tree 8af25e4c88ad055524fa0d456d4ea8ef2177857b 3/34
		010644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 3/34/foo.new
		040000 tree f9af4d60143860a6da76711a24a8a7637abc7bfd 4
		040000 tree 126a0ef9554dbc48cd9c571ca7542e60ee5c72b3 4/45
		010755 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 4/45/bar.new
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO

		===== commit: rm two blobs =====
		040000 tree 810f82d78e5e4ff3f250b0ae8e0816942436d83f .
		040000 tree 49b5cf6a5d0be39aa9997d72a9678b3635c1f4fb 1
		040000 tree 34f40a76b23ff809fa13c509b26299decab17c20 1/12
		040000 tree 3d295d7261fd11c73e48cf96ffc6fb26dd2e00b9 1/12/123
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 1/12/123/bar.1
		040000 tree 556cd61cc7c3b9e1336051de44d46b7ecee61157 2 ( ?)
		040000 tree 82e30a19b4f6c039b11f10e004f14c9d7a06bb10 3
		040000 tree 8af25e4c88ad055524fa0d456d4ea8ef2177857b 3/34
		010644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 3/34/foo.new
		040000 tree f9af4d60143860a6da76711a24a8a7637abc7bfd 4
		040000 tree 126a0ef9554dbc48cd9c571ca7542e60ee5c72b3 4/45
		010755 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 4/45/bar.new
		100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 .gitignore
		100644 blob 5716ca5987cbf97d6bb54920bea6adde242d87e6 BAR
		100644 blob 257cc5642cb1a054f08cc83f2d943e56fd3ebe99 FOO
	EOF
	cat >expect-sha256 <<-\EOF &&
		===== add two blobs =====
		040000 tree 94ad8c1731202698003385f76856d61e5e75637219716d8b7b46170f13c414b9 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		040000 tree                                                                  3 (!?)
		040000 tree                                                                  3/34 (!?)
		010644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 3/34/foo.new
		040000 tree                                                                  4 (!?)
		040000 tree                                                                  4/45 (!?)
		010755 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 4/45/bar.new
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO

		===== commit: add two blobs =====
		040000 tree 516840e6de363b3da4a05e285a6a5df933962c7b4b809566132f06d308725fe7 .
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 ( ?)
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		040000 tree 8e037ced48c9cb00581b0b714f57e33388a704037f49f99df1294a8fb805240b 3
		040000 tree bb681465c57264a3173bd1f293ee95f29a3d7e829c5c10506c3d9f99ca5c72a2 3/34
		010644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 3/34/foo.new
		040000 tree a883c82e4ccf9fe128721e27db99ee2b66cabc1dfe8300c8ad7890cb700c9c35 4
		040000 tree 37cf12b563921ce93667c69f9479f0f8a6184bc83ebb4a19bc06abc1a861d36a 4/45
		010755 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 4/45/bar.new
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO

		===== rm two blobs =====
		040000 tree 516840e6de363b3da4a05e285a6a5df933962c7b4b809566132f06d308725fe7 . (! )
		040000 tree f01207f83d203e6a71c1ae0d34551b21f402cdc22dfa50ec90b1e8c637ed3286 1 (! )
		040000 tree 221d1d056001e7def55977d186d6f17a66c5db8c3ea1d3750ed7f08ab42a7f5e 1/12 (! )
		040000 tree 29c70e77787996bdc0d100c6456b3f90da3f82aeb0d989d0fcb9d4e6255d7571 1/12/123 (! )
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 1/12/123/bar.1
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		040000 tree 8e037ced48c9cb00581b0b714f57e33388a704037f49f99df1294a8fb805240b 3
		040000 tree bb681465c57264a3173bd1f293ee95f29a3d7e829c5c10506c3d9f99ca5c72a2 3/34
		010644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 3/34/foo.new
		040000 tree a883c82e4ccf9fe128721e27db99ee2b66cabc1dfe8300c8ad7890cb700c9c35 4
		040000 tree 37cf12b563921ce93667c69f9479f0f8a6184bc83ebb4a19bc06abc1a861d36a 4/45
		010755 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 4/45/bar.new
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO

		===== commit: rm two blobs =====
		040000 tree d6ae8c22dcc3b8200eeb80cb9c5e45351da652f7fea311fe596afdf5a5bf512f .
		040000 tree 4c7e96380c3a63b002f873205ec682fad8ad436ad74214fafa6e976e86ed2e29 1
		040000 tree cf734ab34ef013b9b8064274d08b19c491b9e50c3169ad6794dcb63a8b55e2b0 1/12
		040000 tree 81b3f85ed240cc1810ea9163245e47782d76f3b0065d433826dc26e016f10c8b 1/12/123
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 1/12/123/bar.1
		040000 tree db4a0079ee23bdd811d3fec2bf0e8ebbdcf1c88607377201b3adcb67f76e3060 2 ( ?)
		040000 tree 8e037ced48c9cb00581b0b714f57e33388a704037f49f99df1294a8fb805240b 3
		040000 tree bb681465c57264a3173bd1f293ee95f29a3d7e829c5c10506c3d9f99ca5c72a2 3/34
		010644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 3/34/foo.new
		040000 tree a883c82e4ccf9fe128721e27db99ee2b66cabc1dfe8300c8ad7890cb700c9c35 4
		040000 tree 37cf12b563921ce93667c69f9479f0f8a6184bc83ebb4a19bc06abc1a861d36a 4/45
		010755 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 4/45/bar.new
		100644 blob 473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813 .gitignore
		100644 blob a52e146ac2ab2d0efbb768ab8ebd1e98a6055764c81fe424fbae4522f5b4cb92 BAR
		100644 blob 47d6aca82756ff2e61e53520bfdf1faa6c86d933be4854eb34840c57d12e0c85 FOO
	EOF
	test_cmp expect-${test_hash_algo} actual &&

	test_file_not_empty result &&
	result=$(cat result) &&
	git -C repo.git diff-tree -r --name-status HEAD $result >changes &&
	cat >expect <<-\EOF &&
		D	1/12/123/foo.1
		D	1/12/124/baz.1
		A	3/34/foo.new
		A	4/45/bar.new
	EOF
	test_cmp expect changes
'

test_done
