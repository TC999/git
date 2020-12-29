#!/bin/sh

# Test crypto on "git-verify-commit"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" bare.git
'

test_expect_success GPG 'create gpg signed commit' '
	git clone --no-local bare.git workdir &&
	(
		cd workdir &&
		touch signed.txt &&
		git add signed.txt &&
		git commit -S -m "Test for signed commit" &&
		git push
	) &&
	S=$(git -C bare.git rev-parse HEAD)
'

test_expect_success GPG 'verify-commit on loose commit object: $S' '
	(
		cd bare.git &&
		git verify-commit -v $S
	)
'

test_expect_success GPG 'verify-commit on packed commit object: $S' '
	(
		cd bare.git &&
		git gc &&
		git verify-commit -v $S
	)
'
