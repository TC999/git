#!/bin/bash

test_description='git receive-pack with alternate ref filtering'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit base &&
	git clone -s --bare . repo
'
oid=$(git rev-parse HEAD)
advertise_refs_first_head=$(git-receive-pack --advertise-refs repo|head -n 1)
advertise_refs_first_len=${advertise_refs_first_head:0:4}

start_receive_pack() {
	git-receive-pack "$@" repo
}

start_proxy_client() {
	printf "00950000000000000000000000000000000000000000 $oid refs/heads/test01\0report-status side-band-64k agent=git/2.24.x\n"
	printf "0000"
	printf "" | git pack-objects --stdout
	msg=
	while read input
	do
		if test -z "$input"
		then
			break
		fi
		printf >&2 "$input\n"
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

test_expect_success 'standard git-receive-pack process' '
	mkfifo pipe &&
	start_receive_pack <pipe | \
		start_proxy_client >pipe 2>actual &&
	cat >expect<<-EOF &&
	$advertise_refs_first_len$oid refs/heads/master
	003c$oid refs/tags/base
	00000030$(printf "\1")000eunpack ok
	0019ok refs/heads/test01
	EOF
	test_cmp expect actual
'

test_expect_success 'cleanup' '
	rm -f pipe &&
	git -C repo update-ref -d refs/heads/test01
'

test_expect_success 'receive pack with txn success' '
	rm -f pipe &&
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client next next >pipe 2>actual &&
	cat >expect<<-EOF &&
	$advertise_refs_first_len$oid refs/heads/master
	003c$oid refs/tags/base
	00000019agit-txn-req-prepare
	00000018agit-txn-req-commit
	00000015agit-txn-req-end
	002echecksum e9c022ff72cf02c8afb901e6d308d05e
	0068$ZERO_OID $oid refs/heads/test01
	00000030$(printf "\1")000eunpack ok
	0019ok refs/heads/test01
	EOF
	test_cmp expect actual
'

test_expect_success 'cleanup' '
	rm -f pipe &&
	git -C repo update-ref -d refs/heads/test01 &&
	git -C repo checksum --init
'

test_expect_success 'txn: prepare failed' '
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client quit >pipe 2>actual &&
	cat >expect <<-EOF &&
	$advertise_refs_first_len$oid refs/heads/master
	003c$oid refs/tags/base
	00000019agit-txn-req-prepare
	00000015agit-txn-req-end
	002echecksum 4d5c7f3a3bf737a341f8d9cd1c659cc7
	0026error transaction prepared failed
	0000004c$(printf "\1")000eunpack ok
	0035ng refs/heads/test01 transaction prepared failed
	EOF
	test_cmp expect actual
'

test_expect_success 'cleanup' '
	rm -f pipe
'

test_expect_success 'txn: commit failed' '
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client next1 quit >pipe 2>actual &&
	cat >expect <<-EOF &&
	$advertise_refs_first_len$oid refs/heads/master
	003c$oid refs/tags/base
	00000019agit-txn-req-prepare
	00000018agit-txn-req-commit
	00000015agit-txn-req-end
	002echecksum 4d5c7f3a3bf737a341f8d9cd1c659cc7
	0024error transaction commit failed
	0000004a$(printf "\1")000eunpack ok
	0033ng refs/heads/test01 transaction commit failed
	EOF
	test_cmp expect actual
'

test_expect_success 'cleanup' '
	rm -f pipe
'

test_expect_success 'setup pre-receive hook' '
	cat >./repo/hooks/pre-receive <<-\EOF &&
	#!/bin/bash
	exit 1
	EOF
	chmod 755 ./repo/hooks/pre-receive
'

test_expect_success 'receive pack with txn but pre hook failed' '
	mkfifo pipe &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client >pipe 2>actual &&
	cat >expect <<-EOF &&
	$advertise_refs_first_len$oid refs/heads/master
	003c$oid refs/tags/base
	00000015agit-txn-req-end
	002echecksum 4d5c7f3a3bf737a341f8d9cd1c659cc7
	0024error pre-receive hook decliend
	0000004a$(printf "\1")000eunpack ok
	0033ng refs/heads/test01 pre-receive hook declined
	EOF
	test_cmp expect actual
'

test_expect_success 'cleanup' '
	rm -f pipe &&
	rm -f ./repo/hooks/pre-receive
'

test_expect_success 'receive pack agit txn receive abnormal pktline' '
	mkfifo pipe &&
	printf "" > actual &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client abnormal >pipe 2>actual &&
	cat >expect <<-EOF &&
	$advertise_refs_first_len$oid refs/heads/master
	003c$oid refs/tags/base
	00000019agit-txn-req-prepare
	EOF
	test_cmp expect actual
'

test_expect_success 'cleanup' '
	rm -f pipe
'

test_expect_success 'receive pack agit txn receive flush pktline' '
	mkfifo pipe &&
	printf "" > actual &&
	start_receive_pack --agit-txn <pipe | \
		start_proxy_client flush >pipe 2>actual &&
	cat >expect <<-EOF &&
	$advertise_refs_first_len$oid refs/heads/master
	003c$oid refs/tags/base
	00000019agit-txn-req-prepare
	00000015agit-txn-req-end
	002echecksum 4d5c7f3a3bf737a341f8d9cd1c659cc7
	0026error transaction prepared failed
	0000004c$(printf "\1")000eunpack ok
	0035ng refs/heads/test01 transaction prepared failed
	EOF
	test_cmp expect actual
'

test_done
