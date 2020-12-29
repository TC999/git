#!/bin/sh

test_description='Test repo encrypt and decrypt

Run all test cases under t0940/test-*.sh using:

    $ sh t0940-crypto-repository.sh

If want to load specific test script inside t0940/, using:

    $ GIT_TEST_LOAD=0001 sh t0940-crypto-repository.sh
'

. ./test-lib.sh

reset_test_tick () {
	# 60s back from initial value in `test-lib-function.sh`
	test_tick=1112911933
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
	hash | 1)
		algo=1
		;;
	aes | 2)
		algo=2
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
				git init .
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
				git init .
			'
			. "$t"
		done
	done
}

run_crypto_test_once

if test -z "$GIT_TEST_CRYPTO_ALGORITHM_TYPE"
then
	setup_env aes
fi
run_crypto_test

test_done
