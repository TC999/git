#!/bin/sh

test_description='agit-gc dryrun test'

. ./test-lib.sh

rewrite_gc_output() {
	sed \
		-e "s/'/\"/g" \
		-e "s/([0-9][0-9][0-9][0-9]* >/(<SIZE> >/g" \
		-e "s/pack-[0-9a-f]\{40\}/pack-<ID>/g"
}

test_expect_success 'Setup' '
	git init --bare repo.git &&
	git -C repo.git config gc.autoDetach 0 && \
	git clone repo.git work
'

test_expect_success 'Setup: add loose objects' '
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
	cat >expect <<-EOF &&
	repo.git/objects/17/5b6c5dfd7f9bf6e2b2c4e2dcf3e2341298575d
	repo.git/objects/17/e344e7c08441fa81d5b56c21008dc0feeeaa20
	EOF
	test_cmp expect actual
'

test_expect_success 'Setup: add packs' '
	git -C repo.git config transfer.unpackLimit 1 &&
	git -C repo.git config gc.auto 0 &&
	(
		cd work &&

		head -c 30720 </dev/urandom >30.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 30.bin" &&
		git push &&

		head -c 61440 </dev/urandom >60.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 60.bin" &&
		git push &&

		head -c 102400 </dev/urandom >100.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 100.bin" &&
		git push &&

		head -c 133120 </dev/urandom >130.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 130.bin" &&
		git push &&

		head -c 163840 </dev/urandom >160.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 160.bin" &&
		git push &&

		head -c 204800 </dev/urandom >200.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 200.bin" &&
		git push &&

		head -c 235520 </dev/urandom >230.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 230.bin" &&
		git push &&

		head -c 266240 </dev/urandom >260.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 260.bin" &&
		git push &&

		head -c 307200 </dev/urandom >300.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 300.bin" &&
		git push &&

		head -c 337920 </dev/urandom >330.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 330.bin" &&
		git push &&

		head -c 368640 </dev/urandom >360.bin &&
		git add -A &&
		test_tick &&
		git commit -m "Add 360.bin" &&
		git push &&

		head -c 409600 </dev/urandom >400.bin &&
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

# (257 + 256 - 1) / 256 = 2
test_expect_success 'gc --auto: repo is healthy' '
	git -C repo.git \
		-c gc.auto=257 \
		gc --auto --dryrun \
		>actual 2>&1 &&

	cat >expect <<-EOF &&
	note: repo is healthy, no need to gc.
	EOF
	test_cmp expect actual
'

# (256 + 256 - 1) / 256 = 1
test_expect_success 'gc --auto: too many loose objects' '
	git -C repo.git \
		-c gc.auto=256 \
		gc --auto --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
	note: too many loose objects, greater than: 1.
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l --no-write-bitmap-index
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	note: too many loose objects, greater than: 1.
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --auto: too many packs, and memory is enough' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		gc --auto --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
	note: too many packs. (12 > 11)
	note: will keep largest pack "./objects/pack/pack-<ID>.pack".
	note: little memory footprint, no pack to keep, and will repack all.
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
	EOF
	test_cmp expect actual
'

test_expect_success 'gc --auto --keep-largest-pack: not keep largest pack for memory is enough' '
	git -C repo.git \
		-c gc.auto=6700 \
		-c gc.autoPackLimit=11 \
		gc --auto --keep-largest-pack --dryrun \
		>out 2>&1 &&
	rewrite_gc_output <out | grep "^note: " >actual &&

	cat >expect <<-EOF &&
	note: too many packs. (12 > 11)
	note: will keep largest pack "./objects/pack/pack-<ID>.pack".
	note: little memory footprint, no pack to keep, and will repack all.
	note: will run: git pack-refs --all --prune
	note: will run: git reflog expire --all
	note: will run: git repack -d -l -A --unpack-unreachable=2.weeks.ago
	note: will run: git prune --expire 2.weeks.ago
	note: will run: git worktree prune --expire 3.months.ago
	note: will run: git rerere gc
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
