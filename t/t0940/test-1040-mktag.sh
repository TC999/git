#!/bin/sh

# Test crypto on "git-mktree"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git &&
	cd bare.git &&
	head=$(git rev-parse --verify HEAD)
'

cat >tag.sig <<EOF
object $head
type commit
tag mytag
tagger T A Gger <tagger@example.com> 0 +0000

This is filler
EOF

test_expect_success 'mktag to create new tag object' '
	oid=$(git mktag <./tag.sig) &&
	git cat-file tag $oid > actual &&
	test_cmp tag.sig actual
'
