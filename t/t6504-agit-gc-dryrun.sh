#!/bin/sh

test_description='agit-gc threshold test'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

create_bare_repo () {
	test "$#" = 1 ||
	BUG "not 1 parameter to test-create-repo"
	repo="$1"
	mkdir -p "$repo"
	(
		cd "$repo" || error "Cannot setup test environment"
		git -c \
			init.defaultBranch="${GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME-master}" \
			init --bare \
			"--template=$GIT_BUILD_DIR/templates/blt/" >&3 2>&4 ||
		error "cannot run git init -- have you built things yet?"
		mv hooks hooks-disabled &&
		git config core.abbrev 7
	) || exit
}

rewrite_gc_output() {
	_x40="$_x35$_x05"

	sed \
		-e "s/'/\"/g" \
		-e "s/([0-9][0-9][0-9][0-9]* >/(<SIZE> >/g" \
		-e "s/pack-$_x40[0-9a-f]*/pack-<ID>/g"
}

test_expect_success 'setup' '
	create_bare_repo repo.git &&
	git -C repo.git config gc.autoDetach 0 &&
	git clone repo.git work
'

if test "$GIT_TEST_DEFAULT_HASH" = sha256
then
	cat >expect <<-EOF
	repo.git/objects/17/3e5dff2e3908c6976be9a1647cc27aca742a3694c8f8f717b06cbace61023b
	repo.git/objects/17/5790306b946f2e4df0e79261dd1c9ceefd40c2d4ae3f8e1a4866ff518dc716
	repo.git/objects/17/744c4d4b03844d2b9eeee3074105289666b7fd9136019fc7e341772abcba71
	repo.git/objects/17/e77a090aae09afc93b3908bf6c57aad56bfec13e6927f47523b02dff5412f0
	EOF
else
	cat >expect <<-EOF
	repo.git/objects/17/5b6c5dfd7f9bf6e2b2c4e2dcf3e2341298575d
	repo.git/objects/17/e344e7c08441fa81d5b56c21008dc0feeeaa20
	EOF
fi

test_expect_success 'setup: add some loose objects' '
	git -C repo.git config transfer.unpackLimit 10000 &&
	(
		cd work &&
		for i in $(test_seq 1 512)
		do
			printf "$i\n" >$i.txt
		done &&
		git add -A &&
		test_tick &&
		git commit -m "Initial commit" &&
		git push
	) &&
	find repo.git/objects/17 -type f | sort >actual &&
	test_cmp expect actual
'

test_expect_success 'setup: add packs' '
	git -C repo.git config transfer.unpackLimit 1 &&
	git -C repo.git config gc.auto 0 &&
	(
		cd work &&

		test_copy_bytes 30720 </dev/urandom >30.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 30.bin" &&
		git push &&

		test_copy_bytes 61440 </dev/urandom >60.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 60.bin" &&
		git push &&

		test_copy_bytes 102400 </dev/urandom >100.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 100.bin" &&
		git push &&

		test_copy_bytes 133120 </dev/urandom >130.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 130.bin" &&
		git push &&

		test_copy_bytes 163840 </dev/urandom >160.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 160.bin" &&
		git push &&

		test_copy_bytes 204800 </dev/urandom >200.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 200.bin" &&
		git push &&

		test_copy_bytes 235520 </dev/urandom >230.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 230.bin" &&
		git push &&

		test_copy_bytes 266240 </dev/urandom >260.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 260.bin" &&
		git push &&

		test_copy_bytes 307200 </dev/urandom >300.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 300.bin" &&
		git push &&

		test_copy_bytes 337920 </dev/urandom >330.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 330.bin" &&
		git push &&

		test_copy_bytes 368640 </dev/urandom >360.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 360.bin" &&
		git push &&

		test_copy_bytes 409600 </dev/urandom >400.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 400.bin" &&
		git push
	)
'

if test "$GIT_TEST_DEFAULT_HASH" = sha256
then
	# SHA256: (769 +256 -1)/256 = 4
	gc_auto_threshold=769
else
	# SHA1:	 (257 + 256 - 1) / 256 = 2
	gc_auto_threshold=257
fi

test_expect_success 'gc: agit.gc is disabled for small repo' '
	(
		cd repo.git &&
		git \
			-c gc.autoPackLimit=5 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=$gc_auto_threshold \
			-c gc.autoDetach=0 \
			-c agit.gc=1 \
			gc --auto --dryrun 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: agit_gc is disabled for repo size below 128MB.
	note: big_pack_threshold is pre-defined as 204800.
	note: too many packs. (12 > 5)
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: too many packs to keep: 7 > 5, clean and use largest one to keep.
	note: will keep largest pack "./objects/pack/pack-<ID>.pack".
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_done

if test "$GIT_TEST_DEFAULT_HASH" = sha256
then
	# SHA256: (769 +256 -1)/256 = 4
	gc_auto_threshold=769
else
	# SHA1:	 (257 + 256 - 1) / 256 = 2
	gc_auto_threshold=257
fi

test_expect_success 'gc: repo is healthy' '
	(
		cd repo.git &&
		AGIT_DEBUG_ASSUME_BIG_REPOSITORY=1 git \
			-c gc.autoPackLimit=5 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=${gc_auto_threshold} \
			-c gc.autoDetach=0 \
			-c agit.gc=1 \
			gc --auto --dryrun 2>&1
	) >actual &&

	cat >expect <<-EOF &&
	note: big_pack_threshold is pre-defined as 204800.
	note: repo is healthy, no need to gc.
	EOF
	test_cmp expect actual
'

if test "$GIT_TEST_DEFAULT_HASH" = sha256
then
	# SHA256: (768 +256 -1)/256 < 4
	gc_auto_threshold=768
	nr_of_files=3
else
	# SHA1:	 (256 + 256 - 1) / 256 < 2
	gc_auto_threshold=256
	nr_of_files=1
fi

test_expect_success 'gc: too many loose objects (agit.gc is not set)' '
	git -C repo.git \
		-c gc.auto=$gc_auto_threshold \
		gc --auto --dryrun \
		>out 2>&1 &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: agit_gc is disabled for repo size below 128MB.
	note: too many loose objects, greater than: $nr_of_files.
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l --no-write-bitmap-index
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	note: too many loose objects, greater than: $nr_of_files.
	EOF
	test_cmp expect actual
'

test_expect_success 'gc: too many loose objects (agit.gc=1)' '
	git -C repo.git \
		-c gc.auto=$gc_auto_threshold \
		-c agit.gc=1 \
		gc --auto --dryrun \
		>out 2>&1 &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: agit_gc is disabled for repo size below 128MB.
	note: too many loose objects, greater than: $nr_of_files.
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l --no-write-bitmap-index
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	note: too many loose objects, greater than: $nr_of_files.
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --auto: with big gc.bigPackThreshold' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		-c agit.gc=1 \
		-c gc.bigPackThreshold=100m \
		gc --auto --dryrun \
		>out 2>&1 &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: agit_gc is disabled for repo size below 128MB.
	note: big_pack_threshold is pre-defined as 104857600.
	note: too many packs. (12 > 11)
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --auto: small threshold 200KB' '
	(
		cd repo.git &&
		AGIT_DEBUG_ASSUME_BIG_REPOSITORY=1 git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=1 \
			gc --auto --dryrun 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: big_pack_threshold is pre-defined as 204800.
	note: too many packs. (5 > 4, excluding 7 keeped pack(s))
	note: always keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 409600).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --auto: small threshold 200KB and keep largest pack' '
	(
		cd repo.git &&
		AGIT_DEBUG_SMALLEST_BIG_PACK_THRESHOLD=0 \
		AGIT_DEBUG_ASSUME_BIG_REPOSITORY=1 git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=1 \
			gc --auto --dryrun 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: big_pack_threshold is pre-defined as 204800.
	note: too many packs. (5 > 4, excluding 7 keeped pack(s))
	note: AGIT_DEBUG_SMALLEST_BIG_PACK_THRESHOLD is set to 0.
	note: always keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 409600).
	note: will keep largest pack "./objects/pack/pack-<ID>.pack".
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc: threshold 200KB' '
	(
		cd repo.git &&
		AGIT_DEBUG_ASSUME_BIG_REPOSITORY=1 git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=1 \
			gc --dryrun 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: big_pack_threshold is pre-defined as 204800.
	note: always keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 409600).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --auto: threshold 200KB, too many packs to keep (agit.gc is disabled)' '
	(
		cd repo.git &&
		git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=0 \
			gc --auto --dryrun 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: too many packs. (12 > 4)
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: too many packs to keep: 7 > 4, clean and use largest one to keep.
	note: will keep largest pack "./objects/pack/pack-<ID>.pack".
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --auto: threshold 200KB, too many packs to keep (agit.gc is disabled)' '
	(
		cd repo.git &&
		git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=0 \
			gc --auto --dryrun 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: too many packs. (12 > 4)
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: too many packs to keep: 7 > 4, clean and use largest one to keep.
	note: will keep largest pack "./objects/pack/pack-<ID>.pack".
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'real gc: threshold 200KB' '
	rm -rf repo1.git &&
	cp -R repo.git repo1.git &&
	(
		cd repo1.git &&
		AGIT_DEBUG_ASSUME_BIG_REPOSITORY=1 git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=1 \
			gc --verbose 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: big_pack_threshold is pre-defined as 204800.
	note: always keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 409600).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual &&

	echo $(ls repo1.git/objects/pack/*.pack | wc -l) >actual &&
	echo 8 >expect &&
	test_cmp expect actual
'

test_expect_success 'real gc --auto: threshold 200KB, too many packs to keep (agit.gc is disabled)' '
	rm -rf repo1.git &&
	cp -R repo.git repo1.git &&
	(
		cd repo1.git &&
		git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=200k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=0 \
			gc --auto --verbose 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: too many packs. (12 > 4)
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
	note: too many packs to keep: 7 > 4, clean and use largest one to keep.
	note: will keep largest pack "./objects/pack/pack-<ID>.pack".
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual &&

	echo $(ls repo1.git/objects/pack/*.pack | wc -l) >actual &&
	echo 2 >expect &&
	test_cmp expect actual
'

test_expect_success 'real gc: threshold 400KB' '
	rm -rf repo1.git &&
	cp -R repo.git repo1.git &&
	(
		cd repo1.git &&
		git \
			-c gc.autoPackLimit=4 \
			-c gc.bigPackThreshold=400k \
			-c gc.auto=6700 \
			-c gc.autoDetach=0 \
			-c agit.gc=1 \
			gc --verbose 2>&1
	) >out &&
	grep "^note: " out | rewrite_gc_output >actual &&

	cat >expect <<-EOF &&
	note: agit_gc is disabled for repo size below 128MB.
	note: big_pack_threshold is pre-defined as 409600.
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 409600).
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago --keep-pack=pack-<ID>.pack
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual &&

	echo $(ls repo1.git/objects/pack/*.pack | wc -l) >actual &&
	echo 2 >expect &&
	test_cmp expect actual
'

test_done
