#!/bin/sh

# Test crypto on "git-clone"

test_expect_success 'clone from common gitdir' '
	git clone --no-local "$COMMON_GITDIR" workdir
'

test_expect_success 'run fsck on workdir' '
	git -C workdir fsck
'

test_expect_success 'check log of main' '
	git -C workdir log --oneline |
		make_user_friendly_and_stable_output >actual &&
	cat >expect <<-EOF &&
	<COMMIT-F> Commit-F
	<COMMIT-C> Commit-C
	EOF
	test_cmp expect actual
'

test_expect_success NEED_GNU_DD 'setup packedgit limited target' '
	rm -rf target.git &&
	git init --bare target.git &&
	git -C target.git config agit.crypto.enabled 1 &&
	git -C target.git config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
	git -C target.git config agit.crypto.nonce random_nonce &&
	git -C target.git config core.packedgitlimit 4k &&
	git -C target.git config pack.packsizelimit 4k
'

test_expect_success NEED_GNU_DD 'add 1mb blob to target' '
	rm -rf workdir &&
	git clone target.git workdir &&
	(
		cd workdir &&
		cat >blob-1m <<-\EOF &&
		blob-1m, which is bigger than 4k.
		EOF
		if type openssl
		then
			openssl enc -aes-256-ctr \
				-pass pass:"$($DD if=/dev/urandom bs=128 count=1 2>/dev/null | base64)" \
				-nosalt < /dev/zero | $DD bs=1024 count=1024 >>blob-1m
		else
			$DD if=/dev/random bs=1024 count=2050 >>blob-1m
		fi &&
		git add blob-1m &&
		test_tick &&
		git commit -m blob-1m &&
		git push origin main
	)
'

test_expect_success NEED_GNU_DD 'make multi pack in target' '
	git -C target.git gc
'

test_expect_success NEED_GNU_DD 'clone from target' '
	git clone --no-local target.git dest
'
