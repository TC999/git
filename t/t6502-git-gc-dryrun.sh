#!/bin/sh

test_description='agit-gc dryrun test'

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

test_expect_success 'setup: add loose objects' '
	git -C repo.git config transfer.unpackLimit 6700 &&
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

test_expect_success 'gc --auto: auto gc is disabled' '
	git -C repo.git \
		gc --auto --dryrun \
		>actual 2>&1 &&

	cat >expect <<-EOF &&
	note: no need to gc, for '"'"'gc.auto == 0'"'"'.
	EOF
	test_cmp expect actual
'

if test "$GIT_TEST_DEFAULT_HASH" = sha256
then
	# SHA256: (769 +256 -1)/256 = 4
	gc_auto_threshold=769
else
	# SHA1:	 (257 + 256 - 1) / 256 = 2
	gc_auto_threshold=257
fi

test_expect_success 'gc --auto: repo is healthy' '
	git -C repo.git \
		-c gc.auto=${gc_auto_threshold} \
		gc --auto --dryrun \
		>actual 2>&1 &&

	cat >expect <<-EOF &&
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

test_expect_success 'gc --auto: too many loose objects' '
	git -C repo.git \
		-c gc.auto=$gc_auto_threshold \
		gc --auto --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
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

test_expect_success 'gc: too many packs, packs all' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		gc --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --keep-largest-pack: keep largest pack' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		gc --keep-largest-pack --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
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

test_expect_success 'gc --aggressive' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		gc --aggressive --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -f --depth=50 --window=250 -A --unpack-unreachable=2.weeks.ago
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --prune=now' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		gc --prune=now --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -a
	note: will run: git prune --expire now
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc with bigPackThreshold' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		-c gc.bigPackThreshold=200k \
		gc --auto --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
	note: too many packs. (12 > 11)
	note: will keep pack "./objects/pack/pack-<ID>.pack" (<SIZE> > 204800).
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

test_done
