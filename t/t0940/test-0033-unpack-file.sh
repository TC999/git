#!/bin/sh

# Test crypto on "git-unpack-file"

#
# File: README.txt      : File: README.txt       : File: topic-1.txt
#                       :                        :
#     +--- o (A)        :      +--- o (D)        :  
#    /                  :     /                  : 
#   /  +-- o (B, v1)    :    /  +-- o (E, v3)    :     
#   | /                 :    | /                 :    +-- o (G) [topic/1]
#   |/                  :    |/                  :   /
# --+----- o (C, V2) ---+----+----- o (F, v4) ---+--+           [master]
#                       :                        :
#        <PACK1>        :         <PACK2>        :
#       unencrypted     :        encrypted       :        encrypted
#
test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success 'unpack-file for unencrypted loose object' '
	oid=$(git -C bare.git rev-parse $A:README.txt) &&
	tmpfile=$(git -C bare.git unpack-file $oid) &&
	cat >expect <<-EOF &&
	Commit-A
	EOF
	test_cmp expect "bare.git/$tmpfile"
'

test_expect_success 'unpack-file for unencrypted packed object' '
	oid=$(git -C bare.git rev-parse $C:README.txt) &&
	tmpfile=$(git -C bare.git unpack-file $oid) &&
	cat >expect <<-EOF &&
	Commit-A
	Commit-B
	Commit-C
	EOF
	test_cmp expect "bare.git/$tmpfile"
'

test_expect_success 'unpack-file for encrypted loose object' '
	oid=$(git -C bare.git rev-parse $G:topic-1.txt) &&
	tmpfile=$(git -C bare.git unpack-file $oid) &&
	cat >expect <<-EOF &&
	Commit-G
	EOF
	test_cmp expect "bare.git/$tmpfile"
'

test_expect_success 'unpack-file for encrypted loose object' '
	oid=$(git -C bare.git rev-parse $F:README.txt) &&
	tmpfile=$(git -C bare.git unpack-file $oid) &&
	cat >expect <<-EOF &&
	Commit-A
	Commit-B
	Commit-C
	Commit-D
	Commit-E
	Commit-F
	EOF
	test_cmp expect "bare.git/$tmpfile"
'
