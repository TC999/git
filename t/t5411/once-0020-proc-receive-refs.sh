test_expect_success "setup receive.procReceiveRefs" '
	git clone --mirror "$upstream" test-config.git &&
	git -C test-config.git config receive.procReceiveRefs "refs/for,refs/review" &&
	git clone test-config.git test-config
'

# Refs of upstream : main(B)
# Refs of workbench: main(B)
# git push         : (A)
test_expect_success "can push to refs/heads/main" '
	(
		cd test-config &&
		git push -f origin $A:main >out 2>&1 &&
		make_user_friendly_and_stable_output <out
	) | tail -1 >actual &&
	cat >expect <<-\EOF &&
	 + <COMMIT-B>...<COMMIT-A> <COMMIT-A> -> main (forced update)
	EOF
	test_cmp expect actual
'

# Refs of upstream : main(A)
# Refs of workbench: main(B)
# git push         :            refs/pull/123/head(B)
test_expect_success "can push to refs/pull/123/head" '
	(
		cd test-config &&
		git push origin $B:refs/pull/123/head >out 2>&1 &&
		make_user_friendly_and_stable_output <out
	) | tail -1 >actual &&
	cat >expect <<-\EOF &&
	 * [new reference]   <COMMIT-B> -> refs/pull/123/head
	EOF
	test_cmp expect actual
'

test_expect_success "need proc-receive hook when pushing refs/for/..." '
	test_must_fail git -C test-config push \
		origin HEAD:refs/for/main/topic1 >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

test_expect_success "need proc-receive hook when pushing refs/review/..." '
	test_must_fail git -C test-config push \
		origin HEAD:refs/review/123 >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

test_expect_success "setup receive.procReceiveRefs" '
	git -C test-config.git config --unset-all receive.procReceiveRefs &&
	git -C test-config.git config receive.procReceiveRefs "!:refs/heads,refs/tags"
'

# Refs of upstream : main(A)  refs/pull/123/head(B)
# Refs of workbench: main(B)
# git push         : (B)
test_expect_success "can push to refs/heads/main" '
	git -C test-config push origin $B:main >out 2>&1 &&
	make_user_friendly_and_stable_output <out |
	tail -1 >actual &&
	cat >expect <<-\EOF &&
	   <COMMIT-A>..<COMMIT-B>  <COMMIT-B> -> main
	EOF
	test_cmp expect actual
'

# Refs of upstream : main(A)  refs/pull/123/head(B)
# Refs of workbench: main(B)
# git push         :                                   refs/tags/test-v1(B)
test_expect_success "can push to refs/tags/test-v1" '
	(
		cd test-config &&
		git push origin $A:refs/tags/test-v1 >out 2>&1 &&
		make_user_friendly_and_stable_output <out
	) | tail -1 >actual &&
	cat >expect <<-\EOF &&
	 * [new tag]         <COMMIT-A> -> test-v1
	EOF
	test_cmp expect actual
'

# Refs of upstream : main(B)  refs/pull/123/head(B)  refs/tags/test-v1
# Refs of workbench: main(B)
# git push                      refs/pull/123/head(B)
test_expect_success "refs/pull/123/head is up-to-date" '
	git -C test-config push \
		origin $B:refs/pull/123/head >actual 2>&1 &&
	cat >expect <<-\EOF &&
	Everything up-to-date
	EOF
	test_cmp expect actual
'

# Refs of upstream : main(B)  refs/pull/123/head(B)  refs/tags/test-v1
# Refs of workbench: main(B)
# git push                      refs/pull/123/head(A)
test_expect_success "need proc-receive to update refs/pull/123/head" '
	test_must_fail git -C test-config push -f \
		origin $A:refs/pull/123/head >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

# Refs of upstream : main(B)  refs/pull/123/head(B)  refs/tags/test-v1
# Refs of workbench: main(B)
# git push                                                                 refs/for/main/topic1
test_expect_success "need proc-receive to push refs/for/main/topic" '
	test_must_fail git -C test-config push \
		origin $A:refs/for/main/topic >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

test_expect_success "setup receive.procReceiveRefs" '
	git -C test-config.git update-ref -d refs/tags/test-v1 &&
	git -C test-config.git update-ref -d refs/pull/123/head &&
	git -C test-config.git config --unset-all receive.procReceiveRefs &&
	git -C test-config.git config --add receive.procReceiveRefs "!:refs/heads,refs/tags" &&
	git -C test-config.git config --add receive.procReceiveRefs "ad:refs/heads" &&
	git -C test-config.git config --add receive.procReceiveRefs "refs/tags"
'

# Refs of upstream : main(B)
# Refs of workbench: main(B)
# git push         : (A)
test_expect_success "can push to refs/heads/main" '
	git -C test-config push -f \
		origin $A:main >out 2>&1 &&
	make_user_friendly_and_stable_output <out |
	tail -1 >actual &&
	cat >expect <<-\EOF &&
	 + <COMMIT-B>...<COMMIT-A> <COMMIT-A> -> main (forced update)
	EOF
	test_cmp expect actual
'

# Refs of upstream : main(B)
# Refs of workbench: main(B)
# git push         :            topic1(A)
test_expect_success "need proc-receive-hook to add new branch" '
	test_must_fail git -C test-config push \
		origin $A:refs/heads/topic1 >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

# Refs of upstream : main(B)
# Refs of workbench: main(B)
# git push         : (delete)
test_expect_success "need proc-receive-hook to remove branch" '
	test_must_fail git -C test-config push \
		origin :refs/heads/main >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

# Refs of upstream : main(B)
# Refs of workbench: main(B)
# git push         :            refs/tags/test-v1(B)
test_expect_success "need proc-receive to create new tag" '
	test_must_fail git -C test-config push \
		origin $A:refs/tags/test-v1 >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

# Refs of upstream : main(B)
# Refs of workbench: main(B)
# git push                      refs/pull/123/head(A)
test_expect_success "need proc-receive to push refs/pull/123/head" '
	test_must_fail git -C test-config push -f \
		origin $A:refs/pull/123/head >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'

# Refs of upstream : main(B)  refs/pull/123/head(B)  refs/tags/test-v1
# Refs of workbench: main(B)
# git push                                                                 refs/for/main/topic1
test_expect_success "need proc-receive to push refs/for/main/topic" '
	test_must_fail git -C test-config push \
		origin $A:refs/for/main/topic >actual 2>&1 &&
	grep "fail to run proc-receive hook" actual
'
