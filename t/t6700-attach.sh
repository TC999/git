#!/bin/sh

test_description='basic git attach test cases'

. ./test-lib.sh

test_expect_success 'setup' '
       test_commit 1st
'

test_expect_success 'attach: add regular files' '
       echo "content of foo" >foo &&
       echo "conteng of bar" >bar &&
       foo_blob=`cat foo | git hash-object --stdin` &&
       bar_blob=`cat bar | git hash-object --stdin` &&
       git attach add foo bar
'
test_done