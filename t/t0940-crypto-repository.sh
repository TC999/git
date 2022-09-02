#!/bin/sh

test_description='Test repo encrypt and decrypt

Run all test cases under t0940/test-*.sh using:

    $ sh t0940-crypto-repository.sh

If want to load specific test script inside t0940/, using:

    $ GIT_TEST_LOAD=0001 sh t0940-crypto-repository.sh

Layout of default repository:

    File: README.txt      : File: README.txt       : File: topic-1.txt
                          :                        :
                          :                        :
        +--- o (A)        :      +--- o (D)        :
       /                  :     /                  :
      /  +-- o (B, v1)    :    /  +-- o (E, v3)    :
      | /                 :    | /                 :    +-- o (G) [topic/1]
      |/                  :    |/                  :   /
    --+----- o (C, V2) ---+----+----- o (F, v4) ---+--+           [main]
                          :                        :
           <PACK1>        :         <PACK2>        :
          unencrypted     :        encrypted       :        encrypted
'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/t0940/common-functions.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

# TODO: CI on Windows will hang for this case.
if test_have_prereq WINDOWS
then
	test_done
fi

create_bare_repo () {
	test "$#" = 1 ||
	BUG "not 1 parameter to create-bare-repo"
	repo="$1"
	mkdir -p "$repo"
	(
		cd "$repo" || error "Cannot setup test environment"
		"${GIT_TEST_INSTALLED:-$GIT_EXEC_PATH}/git$X" -c \
			init.defaultBranch="${GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME-master}" \
			init --bare \
			"--template=$GIT_BUILD_DIR/templates/blt/" >&3 2>&4 ||
		error "cannot run git init -- have you built things yet?"
		mv hooks hooks-disabled &&
		git config core.abbrev 7
	) || exit
}

reset_test_tick () {
	# 60s back from initial value in `test-lib-function.sh`
	test_tick=1112911933
}

show_lo_header () {
	test_copy_bytes 20
}

show_pack_header () {
	case ${GIT_TEST_CRYPTO_ALGORITHM_TYPE} in
	1 | 2)
		hdr_size=24
		;;
	64 | 65)
		hdr_size=12
		;;
	*)
		echo >&2 "ERROR: unknown algorithm"
		return 1
		;;
	esac &&
	test_copy_bytes $hdr_size
}

# Some absolute path tests should be skipped on Windows due to path mangling
# on POSIX-style absolute paths
case $(uname -s) in
*MINGW*)
	;;
*CYGWIN*)
	;;
*)
	test_set_prereq POSIX
	;;
esac

if dd --help | grep -q -w iflag
then
	DD="dd iflag=fullblock"
else
	DD=dd
fi

if type openssl || test "$DD" != "dd"
then
	test_set_prereq NEED_GNU_DD
fi

setup_env () {
	algo=

	if test $# -ne 1
	then
		echo >&2 "usage: run_crypto_test <algo>"
		return 1
	fi

	case $1 in
	benchmark | 1)
		algo=1
		;;
	easy_benchmark | 64)
		algo=64
		;;
	aes | 2)
		algo=2
		;;
	easy_aes | 65)
		algo=65
		;;
	default)
		algo=
		;;
	*)
		echo >&2 "error: bad algorithm: $1"
		return 1
		;;
	esac

	test_expect_success "========== Setup algorithm: algorithm: $algo ==========" '
		if test -n "$algo"
		then
			GIT_TEST_CRYPTO_ALGORITHM_TYPE=$algo &&
			export GIT_TEST_CRYPTO_ALGORITHM_TYPE
		else
			unset GIT_TEST_CRYPTO_ALGORITHM_TYPE
		fi
	'

	COMMON_GITDIR="$TRASH_DIRECTORY/common-${GIT_TEST_CRYPTO_ALGORITHM_TYPE}.git"
}

run_crypto_test_once () {
	if test -z "$GIT_TEST_LOAD"
	then
		GIT_TEST_LOAD="[0-9][0-9][0-9][0-9]"
	fi

	for num in $GIT_TEST_LOAD
	do
		for t in "$TEST_DIRECTORY"/t0940/once-$num-*.sh
		do
			if test ! -e "$t"
			then
				echo >&2 "ERROR: no such file: $t"
				continue
			fi
			name=$(basename $t)
			name=${name%.sh}
			SUB_TRASH_DIRECTORY="$TRASH_DIRECTORY/$name"
			mkdir -p "$SUB_TRASH_DIRECTORY"
			cd "$SUB_TRASH_DIRECTORY"
			reset_test_tick
			test_expect_success "********** Start $name **********" '
				test_create_repo .
			'
			. "$t"
		done
	done
}

run_crypto_test () {
	reset_test_tick &&
	cd "$TRASH_DIRECTORY" &&

	test_expect_success "common: init gitdir" '
		rm -rf "$COMMON_GITDIR" &&
		create_bare_repo "$COMMON_GITDIR" &&
		git -C "$COMMON_GITDIR" config receive.unpackLimit 100 &&
		git -C "$COMMON_GITDIR" config core.abbrev 7 &&
		git clone "$COMMON_GITDIR" workdir &&
		test -d "$COMMON_GITDIR"
	'

	test_expect_success "common: first round of push" '
		# loose commit, which need to prune (no reference linked with it)
		test_commit_setvar -C workdir A "Commit-A" README.txt &&
		git -C workdir push &&

		# amend to create loose commit A, which will have a tag linked with it.
		test_commit_setvar -C workdir --append --amend B "Commit-B" README.txt &&
		git -C workdir push -f &&

		# amend to create commit B, which will be packed later
		test_commit_setvar -C workdir --append --amend C "Commit-C" README.txt &&
		git -C workdir push -f
	'

	test_expect_success "common: run git-gc to create unencrypted pack" '
		git -C "$COMMON_GITDIR" gc &&
		PACK1=$(ls "$COMMON_GITDIR/objects/pack/" | grep "pack$" | sed -e "s/.*pack-\(.*\).pack$/\1/") &&
		test -f "$COMMON_GITDIR"/objects/pack/pack-$PACK1.pack &&
		touch   "$COMMON_GITDIR"/objects/pack/pack-$PACK1.keep &&
		git -C "$COMMON_GITDIR" fsck
	'

	test_expect_success "common: enable crypto settings" '
		git -C "$COMMON_GITDIR" config agit.crypto.enabled 1 &&
		git -C "$COMMON_GITDIR" config agit.crypto.secret c2VjcmV0LXRva2VuMTIzNA== &&
		git -C "$COMMON_GITDIR" config agit.crypto.nonce random_nonce
	'

	test_expect_success "common: 2nd round of push" '
		# loose encrypted commit, which need to prune (no reference linked with it)
		test_commit_setvar -C workdir --append D "Commit-D" README.txt &&
		git -C workdir push &&

		# loose encrypted commit, which will have a tag linked
		test_commit_setvar -C workdir --append --amend E "Commit-E" README.txt &&
		git -C workdir push -f &&

		# push the amended commit, so there will be a loos commit after git-gc
		test_commit_setvar -C workdir --append --amend F "Commit-F" README.txt &&
		git -C workdir push -f
	'

	test_expect_success "common: run git-gc to create encrypted pack" '
		git -C "$COMMON_GITDIR" gc &&
		PACK2=$(ls "$COMMON_GITDIR/objects/pack/" | grep "pack$" | grep -v "$PACK1" | sed -e "s/.*pack-\(.*\).pack$/\1/") &&
		test -f "$COMMON_GITDIR"/objects/pack/pack-$PACK2.pack &&
		touch   "$COMMON_GITDIR"/objects/pack/pack-$PACK2.keep &&
		git -C "$COMMON_GITDIR" fsck
	'

	test_expect_success "common: create new branch" '
		git -C workdir checkout -b topic/1 &&
		test_commit_setvar -C workdir --append G "Commit-G" topic-1.txt &&
		git -C workdir push -u origin topic/1
	'

	test_expect_success "common: create tags" '
		test_commit_setvar -C workdir --tag TAG1 v1 $B &&
		test_commit_setvar -C workdir --tag TAG2 v2 $C &&
		test_commit_setvar -C workdir --tag TAG3 v3 $E &&
		test_commit_setvar -C workdir --tag TAG4 v4 $F &&
		git -C workdir push origin --tags
	'

	test_expect_success "common: show-ref" '
		git -C "$COMMON_GITDIR" show-ref |
			make_user_friendly_and_stable_output >actual &&
		cat >expect <<-EOF &&
		<COMMIT-F> refs/heads/main
		<COMMIT-G> refs/heads/topic/1
		<TAG-1> refs/tags/v1
		<TAG-2> refs/tags/v2
		<TAG-3> refs/tags/v3
		<TAG-4> refs/tags/v4
		EOF
		test_cmp expect actual
	'

	test_expect_success "common: cleanup" '
		rm -rf workdir
	'

	if test -z "$GIT_TEST_LOAD"
	then
		GIT_TEST_LOAD="[0-9][0-9][0-9][0-9]"
	fi

	for num in $GIT_TEST_LOAD
	do
		for t in "$TEST_DIRECTORY"/t0940/test-$num-*.sh
		do
			if test ! -e "$t"
			then
				echo >&2 "ERROR: no such file: $t"
				continue
			fi
			name=$(basename $t)
			name=${name%.sh}
			SUB_TRASH_DIRECTORY="$TRASH_DIRECTORY/$name-${GIT_TEST_CRYPTO_ALGORITHM_TYPE}"
			mkdir -p "$SUB_TRASH_DIRECTORY"
			cd "$SUB_TRASH_DIRECTORY"
			reset_test_tick
			test_expect_success "********** Start $name (${GIT_TEST_CRYPTO_ALGORITHM_TYPE}) **********" '
				test_create_repo .
			'
			. "$t"
		done
	done
}

run_crypto_test_once

for algo in ${algorithms:=aes easy_aes}
do
	setup_env $algo
	run_crypto_test
done

test_done
