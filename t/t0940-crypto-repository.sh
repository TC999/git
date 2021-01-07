#!/bin/sh

test_description='Test repo encrypt and decrypt

Run all test cases under t0940/test-*.sh using:

    $ sh t0940-crypto-repository.sh

If want to load specific test script inside t0940/, using:

    $ GIT_TEST_LOAD=0001 sh t0940-crypto-repository.sh
'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

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
