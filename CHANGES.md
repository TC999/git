How to merge all topic branches
===============================

Release all topic branches to agit-master branch based on v2.36.2 and agit version 6.5.9:
1. Update GIT-VERSION contents to v2.36.2
2. Update PATCH-VERSION contents to 6.5.9
3. Run make, will build 'patchwork' binary
4. Export patches:
```shell
./patchwork export-patches
```
5. Apply patches:
```shell
./patchwork apply-patches --apply-to <the git repo path>
```

AGIT Release Notes
==================


v6.6.0-dev
----------
* refactor-refs-txn: new topic to fix "reference-transaction" hook.
* refs-txn-hook: rebase to "refactor-refs-txn" and refactor internal
  pre-txn-hook and post-txn-hook based on "reference-transaction"
  hook.
* black-hole: refactor from one commit to several commits.
* agit-gc: refactor to improve readability.
* auto-gc-if-too-many-loose-refs: ignore "\*.lock" files when checking
  loose references.
* auto-gc-if-too-many-loose-refs: fix memory leak by release buf.
* write-packed-refs: do not pack unfetched references.
* write-packed-refs: rebased to "refactor-refs-txn".
* Remove topic end-of-options.
* commit-graph-genv2-upgrade-fix: fix the commit-graph bug introduced 
  in Git version v2.36.1. This patch Git has been merged into v2.37.2,
  if we use v2.37.2 and later to package, then this patch needs to be 
  discarded.
* pack-objects-hook-agit-clause: introduce new configuration to improve
  the cache hit rate of pack-objects.

v6.5.9
------
* builtin/repack.c: ensure that names is sorted
* http: support read netrc file from a specific path

v6.5.6
------
* receive-pack: record large blobs into "info/large-blobs" and add
  "receive.maxInputBlobSize" in addtion to
  "receive.maxInputObjectSize".

v6.5.5
------
* unpack-objects: unpack large blob in stream.

v6.5.4
------
* upload-pack: call pre-send-pack hook to send notifications

v6.5.3
------
* receive-pack: not receive pack file with large object.
* http: add http.maxReceiveSpeed to limit receiving speed of "git-receive-pack".

v6.5.2
------
* 修改 "setup_revisions()"，支持在 "--end-of-options" 参数之后解析 "--not", "--all" 等 revision_pseudo_opts.

v6.5.1
------
* 默认关闭对 git-upload-pack 和 git-receive-pack 的 loadavg 限流，可以通过环境变量
  "AGIT_LOAD_AVG_ENABLED=1" 或者 git 配置变量 "agit.loadavgEnabled=1" 开启限流。
  默认关闭限流可以避免测试用例因限流失败。

v6.5.0
------
* 修正测试用例，集成分支在 GitHub 上全量测试通过。
* 测试用例：使用 `GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main` 设置缺省分支名为
  main，避免在强制指定默认分支的测试条件下失败。
* 测试用例：创建仓库使用 test_create_repo或者新封装的 create_bare_repo，以便
  创建仓库能够读取 GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME环境变量，创建仓库使用
  预期的默认分支。
* 测试用例：使用自定义方法 `make_user_friendly_and_stable_output` 对输出中的
  提交 ID 做替换，以避免在仓库格式为 SHA256 条件下，提交ID的不一致。
* 测试用例：使用不同仓库哈希算法，git 传输字节有变动，对传输字节的测试进行替换。
* 测试用例：使用 prereq 或者其他方式绕过对 git-checksum工具的依赖。
* 代码中 printf 语句在显示 `unsigned long` 等跨平台长度不一致变量显示的兼容问题，
  使用强制类型转换，及 %"PRIu64"类似方式。例如:

        fprintf(stderr, 
                 "local: read %"PRIu64" from server...\t\r", 
                 (uint64_t)total);

* 优化特性 `topic/0070-agit-gc` 的实现。
* 限速功能会因为测试时CPU过载导致部分用例执行失败。添加配置变量
  `agit.loadavgEnabled`，并在测试用例中关闭。
* 使用 GitHub 上的私有仓库 `gotgit/private-git` 对集成分支进行全量测试.


v6.4.1
------
* TDE: reduce decrypt size if zlib stream.avali_out is less than size of decrypt buffer.

v6.3.1
------
* TDE: Add new crypto algo aes x4. AES_X4(algo type 3) will repeat each byte 
  of seq for 4 times, and encrypt 64 bytes once. In this mode, we only need 
  1/4 of calls to do encryption.


v6.2.2
------
* TDE: bugfix on creating random nonce.


v6.2.1
-----
* Introduce TDE (transparent-data-encryption).

  - [update] support 24 bytes' header for packfile and fix bug when reuse pack data in encrypted repo with bitmap
    enabled


v6.1.5
-----
* Introduce TDE (transparent-data-encryption).

  - [update] fix bug when reuse pack data in encrypted repo with bitmap
    enabled.

* receive-pack: report fallback to atomic push using rp_warning
  instead of rp_error.  Fallback to atomic push will increase
  speed to update repository checksum when there are lots of
  references need to be updated.


v6.1.2
------
* Introduce TDE (transparent-data-encryption).

  - [update] fix bug when reuse pack data in encrypted repo with bitmap
    enabled.

* receive-pack: report fallback to atomic push using rp_warning
  instead of rp_error.  Fallback to atomic push will increase
  speed to update repository checksum when there are lots of
  references need to be updated.


v6.0.1
------
* git-bundle: Merge upstream improvements, which add --stdin support.
* proc-receive-hook: Merge upstream improvements on test.


v6.0
-----
* Base version: git 2.28.0.
* Use "jx/proc-receive-hook" topic instead of "execute-command" hook.


v5.4
-----
* Base version: git 2.24.1.
* agit.gc mode: set big pack threshold automatically for git-gc.


v5.3
-----
* git-checksum: read ref update cmd from args.
* git-checksum: save log to file .git/info/checksum.log.


v5.2
-----
* galileo: refactor agit protocol extension.
* galileo: return commands list in agit-txt-req-end request.


v5.0
-----
* galileo: protocol extension for galileo project with new agit-txn capability.


v4.5
-----
* agit-flow: parse output of `execute-commands` to env_argv and pass to `post-receive`.


v4.4
-----
* checksum: fallback to atomic push, if too many commands (>100) in one push.
* agit-flow: fail if there is a special push, but 'execute-commands' hook not exist.
* agit-flow: add help for hooks.


v4.3
-----
* Suppress error message if "git-checksum" is not installed.
* refactor agit-flow patches.


v4.2
------
* Generate checksum file after writing to repository.
* Add more test cases.
* Rebase to Git 2.24.1.


v3
------
* Git traffic protection by checking loadavg.


v2
------
* Fix dirname bug, which not work well in MacOS.
* Add test cases for git-receive-pack for execute-commands hook.
* Add test cases for last-modified timestamp and agit-repo.lock.


v1
------
* New command 'git-quiltexport' to export commits to quilt patches.
* Prohibit to write to repo if there is a 'agit-repo.lock' file at any upword directory.
* Touch a '.git/info/last-modified' file after write to repo.
* In order to support centralize workflow like gerrit in git, add a `.git/hooks/execute-commands`
  hook.  If user has set `receive.executeCommandsRefs` config variables, git will check and mark
  commands, and run external hook instead of internal functions on marked commands.
