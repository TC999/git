#!/bin/bash

test_description='git receive-pack with alternate ref filtering'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

make_stable_pktline_output () {
	perl -p -e '
		s#([0-9a-f]{4}checksum) [0-9a-f]*#\1 <checksum>#;
		s#( refs/heads/main).*$#\1#;
	'
}

start_receive_pack() {
	git-receive-pack "$@" repo
}

start_proxy_client() {
	if test "$GIT_TEST_DEFAULT_HASH" = sha256
	then
		printf "00da$ZERO_OID $txn_tip refs/heads/test01\0report-status side-band-64k object-format=sha256 agent=git/2.24.x\n"
	else
		printf "0095$ZERO_OID $txn_tip refs/heads/test01\0report-status side-band-64k agent=git/2.24.x\n"
	fi
	printf "0000"
	printf "" | git pack-objects --stdout
	msg=
	while read input
	do
		if test -z "$input"
		then
			break
		fi

		printf "$input\n" >&7

		if echo "$input" | grep -q "agit-txn-req" && test $# -gt 0
		then
			case $1 in
			next0 | next)
				printf "0019agit-txn-resp-next 0\n"
				;;
			next1)
				printf "0019agit-txn-resp-next 1\n"
				;;
			quit)
				printf "0017agit-txn-resp-quit\n"
				;;
			flush)
				printf "0000"
				;;
			abnormal)
				printf "EOF\n"
				;;
			esac
			shift
		fi
	done
}

if test "$GIT_TEST_DEFAULT_HASH" = sha256
then
	pktline_len_branch_main=0055
	pktline_len_tag_base=0054
	pktline_len_update_branch_test01=0098
else
	pktline_len_branch_main=003d
	pktline_len_tag_base=003c
	pktline_len_update_branch_test01=0068
fi

test_expect_success PIPE 'setup' '
	test_commit base &&
	git clone -s --bare . repo &&
	txn_tip=$(git rev-parse HEAD) &&
	advertise_refs_first_line=$(git-receive-pack --advertise-refs repo|head -n 1) &&
	suffix=${advertise_refs_first_line#????} &&
	pktline_len_branch_main=${advertise_refs_first_line%$suffix}
'

test_expect_success PIPE 'standard git-receive-pack process' '
	mkfifo pipe &&
	start_receive_pack <pipe | \
		start_proxy_client >pipe 7>out &&
	make_stable_pktline_output <out >actual &&
	cat >expect<<-EOF &&
	${pktline_len_branch_main}${txn_tip} refs/heads/main
	${pktline_len_tag_base}${txn_tip} refs/tags/base
	00000030$(printf "\1")000eunpack ok
	0019ok refs/heads/test01
	EOF
	test_cmp expect actual
'

test_expect_success PIPE 'cleanup' '
	rm -f pipe &&
	git -C repo update-ref -d refs/heads/test01
'

test_expect_success PIPE 'create 32-byte checksum file (in case no git-checksum installed)' '
	cat >repo/info/checksum <<-EOF
	12345678901234567890123456789012
	EOF
'

test_expect_success PIPE 'receive pack with txn success' '
	rm -f pipe &&
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client next next >pipe 7>out &&
	make_stable_pktline_output <out >actual &&
	cat >expect<<-EOF &&
	${pktline_len_branch_main}${txn_tip} refs/heads/main
	${pktline_len_tag_base}${txn_tip} refs/tags/base
	00000019agit-txn-req-prepare
	00000018agit-txn-req-commit
	00000015agit-txn-req-end
	002echecksum <checksum>
	${pktline_len_update_branch_test01}$ZERO_OID $txn_tip refs/heads/test01
	00000030$(printf "\1")000eunpack ok
	0019ok refs/heads/test01
	EOF
	test_cmp expect actual
'

test_expect_success PIPE 'cleanup' '
	rm -f pipe &&
	git -C repo update-ref -d refs/heads/test01
'

test_expect_success PIPE 'txn: prepare failed' '
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client quit >pipe 7>out &&
	make_stable_pktline_output <out >actual &&
	cat >expect <<-EOF &&
	${pktline_len_branch_main}${txn_tip} refs/heads/main
	${pktline_len_tag_base}${txn_tip} refs/tags/base
	00000019agit-txn-req-prepare
	00000015agit-txn-req-end
	002echecksum <checksum>
	0026error transaction prepared failed
	0000004c$(printf "\1")000eunpack ok
	0035ng refs/heads/test01 transaction prepared failed
	EOF
	test_cmp expect actual
'

test_expect_success PIPE 'cleanup' '
	rm -f pipe
'

test_expect_success PIPE 'txn: commit failed' '
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client next1 quit >pipe 7>out &&
	make_stable_pktline_output <out >actual &&
	cat >expect <<-EOF &&
	${pktline_len_branch_main}${txn_tip} refs/heads/main
	${pktline_len_tag_base}${txn_tip} refs/tags/base
	00000019agit-txn-req-prepare
	00000018agit-txn-req-commit
	00000015agit-txn-req-end
	002echecksum <checksum>
	0024error transaction commit failed
	0000004a$(printf "\1")000eunpack ok
	0033ng refs/heads/test01 transaction commit failed
	EOF
	test_cmp expect actual
'

test_expect_success PIPE 'cleanup' '
	rm -f pipe
'

test_expect_success PIPE 'setup pre-receive hook' '
	cat >./repo/hooks/pre-receive <<-\EOF &&
	#!/bin/bash
	exit 1
	EOF
	chmod 755 ./repo/hooks/pre-receive
'

test_expect_success PIPE 'receive pack with txn but pre hook failed' '
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client >pipe 7>out &&
	make_stable_pktline_output <out >actual &&
	cat >expect <<-EOF &&
	${pktline_len_branch_main}${txn_tip} refs/heads/main
	${pktline_len_tag_base}${txn_tip} refs/tags/base
	00000015agit-txn-req-end
	002echecksum <checksum>
	0024error pre-receive hook decliend
	0000004a$(printf "\1")000eunpack ok
	0033ng refs/heads/test01 pre-receive hook declined
	EOF
	test_cmp expect actual
'

test_expect_success PIPE 'cleanup' '
	rm -f pipe &&
	rm -f ./repo/hooks/pre-receive
'

test_expect_success PIPE 'receive pack agit txn receive abnormal pktline' '
	mkfifo pipe &&
	printf "" > actual &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client abnormal >pipe 7>out &&
	make_stable_pktline_output <out >actual &&
	cat >expect <<-EOF &&
	${pktline_len_branch_main}${txn_tip} refs/heads/main
	${pktline_len_tag_base}${txn_tip} refs/tags/base
	00000019agit-txn-req-prepare
	EOF
	test_cmp expect actual
'

test_expect_success PIPE 'cleanup' '
	rm -f pipe
'

test_expect_success PIPE 'receive pack agit txn receive flush pktline' '
	mkfifo pipe &&
	printf "" > actual &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client flush >pipe 7>out &&
	make_stable_pktline_output <out >actual &&
	cat >expect <<-EOF &&
	${pktline_len_branch_main}${txn_tip} refs/heads/main
	${pktline_len_tag_base}${txn_tip} refs/tags/base
	00000019agit-txn-req-prepare
	00000015agit-txn-req-end
	002echecksum <checksum>
	0026error transaction prepared failed
	0000004c$(printf "\1")000eunpack ok
	0035ng refs/heads/test01 transaction prepared failed
	EOF
	test_cmp expect actual
'

test_done
