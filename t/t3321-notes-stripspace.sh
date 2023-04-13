#!/bin/sh
#
# Copyright (c) 2007 Teng Long
#

test_description='Test commit notes with stripspace behavior'

. ./test-lib.sh

consecutive_newlines="$LF$LF$LF"

test_expect_success 'add note with "-m"' '
	test_commit 1st &&
	cat >expect <<-EOF &&
		first-line

		second-line

		third-line
	EOF

	git notes add -m "${LF}first-line${LF}${LF}second-line${consecutive_newlines}third-line${LF}${LF}" &&
	git notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'add note with multiple "-m"' '
	test_commit 2nd &&
	cat >expect <<-EOF &&
		first-line

		second-line

		third-line
	EOF

	git notes add -m "${LF}" \
		      -m "first-line" \
		      -m "${LF}${LF}" \
		      -m "second-line" \
		      -m "${consecutive_newlines}" \
		      -m "third-line" \
		      -m "${LF}" &&
	git notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'add note with "-F"' '
	test_commit 3rd &&
	cat >expect <<-EOF &&
		file-1-first-line

		file-1-second-line

		file-2-first-line

		file-2-second-line
	EOF

	cat >note-file-1 <<-EOF &&
		${LF}
		file-1-first-line
		${consecutive_newlines}
		file-1-second-line
		${LF}
	EOF

	cat >note-file-2 <<-EOF &&
		${LF}
		file-2-first-line
		${consecutive_newlines}
		file-2-second-line
		${LF}
	EOF

	git notes add -F note-file-1 -F note-file-2 &&
	git notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'reuse with "-C" will not do stripspace' '
	test_commit 4th &&
	cat >expect <<-EOF &&
		${LF}
		first-line
		${consecutive_newlines}
		second-line
		${LF}
	EOF

	cat expect | git hash-object -w --stdin >blob &&
	git notes add -C $(cat blob) &&
	git notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'reuse with "-C" and "-m" (order matters) will do stripspace together' '
	test_commit 5th &&
	cat >data <<-EOF &&
		${LF}
		first-line
		${consecutive_newlines}
		second-line
		${LF}
	EOF

	cat >expect <<-EOF &&
		first-line

		second-line

		third-line
	EOF

	cat data | git hash-object -w --stdin >blob &&
	git notes add -C $(cat blob) -m "third-line" &&
	git notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'reuse with "-m" and "-C" (order matters) will do stripspace together' '
	test_commit 6th &&
	cat >data <<-EOF &&
		${LF}
		second-line
		${consecutive_newlines}
		third-line
		${LF}
	EOF

	cat >expect <<-EOF &&
		first-line
		${LF}
		second-line
		${consecutive_newlines}
		third-line
		${LF}
	EOF

	cat data | git hash-object -w --stdin >blob &&
	git notes add -m "first-line" -C $(cat blob)  &&
	git notes show >actual &&
	test_cmp expect actual
'

test_done
