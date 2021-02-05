#!/bin/sh

# Test crypto on "git-decrypt"

test_expect_success 'setup' '
	cp -a "$COMMON_GITDIR" encrypted.git
'

test_expect_success 'turn off crypto settings' '
	git -C encrypted.git config agit.crypto.enabled 0 &&
	git -C encrypted.git config --unset agit.crypto.secret &&
	rm -f encrypted.git/objects/pack/pack-*.keep
'

test_expect_success 'failed to run git fsck for encrypted repo' '
	test_must_fail git -C encrypted.git fsck
'

test_expect_success 'git decrypt success' '
	GIT_CONFIG_PARAMETERS="${SQ}agit.crypto.secret=nekot-terces${SQ}" \
		git -C encrypted.git decrypt
'

test_expect_success 'git fsck' '
	git -C encrypted.git fsck
'
