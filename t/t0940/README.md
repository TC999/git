# 运行测试用例

运行 `t0940/` 下所有测试用例，使用命令：

    $ cd t/
    $ sh t0940-crypto-repository.sh

如果只想执行 `t0940/` 下的部分命令，执行：

    $ GIT_TEST_LOAD=0001 sh t0940-crypto-repository.sh


# 服务端核心 Git 命令测试覆盖

    命令                          | 测试用例
    ------------------------------|----------------------------
    annotate                      | 0009
    archive                       | 0008
    blame                         | 0009
    branch                        | 0010
    bundle                        | 0011
    cat-file                      | 0012
    clone                         | 0004
    commit-tree                   | 0013
    config                        | 0001
    count-objects                 | 0014
    describe                      | 0015
    diff                          | 0016
    fast-export                   | 0038
    fast-import                   | 0038
    fetch                         | 0005
    format-patch                  | 0017
    fsck                          | 0002
    gc                            | 0001
    hash-object                   | 0018 0022 0036
    http-push                     | 0006
    init                          | 0000
    log                           | 0013 0019
    ls-tree                       | 0020 0022 0036
    merge-base                    | 0021
    mktree                        | 0022 0036
    multi-pack-index              | 0023
    name-rev                      | 0024
    pack-refs                     | 0025
    prune                         | 0026
    push                          | 0003 0006
    read-tree                     | 0027 0036
    rev-list                      | 0007
    rev-parse                     | 0013 0028
    show                          | 0029
    show-ref                      | 0030
    tag                           | 0031
    unpack-file                   | 0033
    unpack-objects                | 0037
    update-ref                    | 0013 0032
    upload-archive                | 0008
    verify-commit                 | 0034
    verify-pack                   | 0035
    verify-tag                    | 0031
    write-tree                    | 0036


# 其他 Git 命令测试覆盖

    命令                          | 测试用例
    ------------------------------|----------------------------
    add                           |
    am                            |
    apply                         |
    archimport                    |
    bisect                        |
    bisect--helper                |
    bugreport                     |
    check-attr                    |
    check-ignore                  |
    check-mailmap                 |
    check-ref-format              |
    checkout                      |
    checkout-index                |
    cherry                        |
    cherry-pick                   |
    citool                        |
    clean                         |
    column                        |
    commit                        |
    commit-graph                  |
    credential                    |
    credential-cache              |
    credential-cache--daemon      |
    credential-store              |
    cvsexportcommit               |
    cvsimport                     |
    cvsserver                     |
    daemon                        |
    diff-files                    |
    diff-index                    |
    diff-tree                     |
    difftool                      |
    difftool--helper              |
    env--helper                   |
    fetch-pack                    |
    filter-branch                 |
    fmt-merge-msg                 |
    for-each-ref                  |
    for-each-repo                 |
    fsck-objects                  |
    get-tar-commit-id             |
    grep                          |
    gui                           |
    gui--askpass                  |
    help                          |
    http-backend                  |
    http-fetch                    |
    http-push                     |
    imap-send                     |
    index-pack                    |
    init-db                       |
    instaweb                      |
    interpret-trailers            |
    ls-files                      |
    ls-remote                     |
    mailinfo                      |
    mailsplit                     |
    maintenance                   |
    merge                         |
    merge-file                    |
    merge-index                   |
    merge-octopus                 |
    merge-one-file                |
    merge-ours                    |
    merge-recursive               |
    merge-recursive-ours          |
    merge-recursive-theirs        |
    merge-resolve                 |
    merge-subtree                 |
    merge-tree                    |
    mergetool                     |
    mktag                         |
    mv                            |
    notes                         |
    p4                            |
    pack-objects                  |
    pack-redundant                |
    patch-id                      |
    pickaxe                       |
    prune-packed                  |
    pull                          |
    quiltimport                   |
    range-diff                    |
    rebase                        |
    rebase--interactive           |
    receive-pack                  |
    reflog                        |
    remote                        |
    remote-ext                    |
    remote-fd                     |
    remote-ftp                    |
    remote-ftps                   |
    remote-http                   |
    remote-https                  |
    repack                        |
    replace                       |
    request-pull                  |
    rerere                        |
    reset                         |
    restore                       |
    revert                        |
    rm                            |
    send-email                    |
    send-pack                     |
    sh-i18n--envsubst             |
    shell                         |
    shortlog                      |
    show-branch                   |
    show-index                    |
    sparse-checkout               |
    stage                         |
    stash                         |
    status                        |
    stripspace                    |
    submodule                     |
    submodule--helper             |
    svn                           |
    switch                        |
    symbolic-ref                  |
    update-index                  |
    update-server-info            |
    upload-archive--writer        |
    upload-pack                   |
    var                           |
    version                       |
    web--browse                   |
    whatchanged                   |
    worktree                      |
