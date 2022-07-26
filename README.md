# AGit 项目维护
阿里巴巴维护的自定义 Git 版本成为 AGit，其中包含大量私有特性，AGit 的代码协同和发布流程简述如下：
1. 每一个特性包含一个或多个提交，特性分支命名（为了保持一致）：topic/NNNN-\<name\>，具体可参见已有的分支
2. 目前所有已经发布的特性分支记录到了 `topic.txt` 文件中，这个文件的书写格式比较随意，不需要 `topic/NNNN-` 前缀，具体可以参见文件中已经书写过的分支
3. 编辑 GIT-VERSION 文件，修改成我们要使用的 Git 版本，例如：v2.36.2
4. 编辑 PATCH-VERSION 文件，修改成我们要发布的 AGit 版本，例如：6.5.9
5. 然后执行 `make export-patches` 会在当前 `patches` 目录下生成对应的补丁文件信息
6. 将生成好的 `patches` 目录中的内容覆盖到仓库 [omnibus-git](https://code.aone.alibaba-inc.com/agit/omnibus-git) 中的 [config/patches/git](https://code.alibaba-inc.com/agit/omnibus-git/tree/master/config/patches/git) 目录下，并由改仓库执行相关发布脚本，最终生成 AGit 安装包
7. 生成好的 rpm 包我们会集中上传到 OSS 上，bucket 地址：[oss://force-aliyun-oss-pre/agit/](oss://force-aliyun-oss-pre/agit/)

## 项目目录文件描述
* patches 目录：会记录对应 Git 版本生成的补丁文件
* util 目录：patchwork 工具的源码目录，用来方便我们快速生成 patches 以及引用这些 patches
* CHANGES.md 文件：记录每个版本的发布内容
* GIT-VERSION 文件：用来标记目前所使用的 Git 版本，这个文件会被 patchwork 工具读取
* PATCH-VERSION 文件：用来标记目前 AGit 的版本，这个文件会被 patchwork 工具读取
* topic.txt 文件：用来记录我们目前所发布的特性分支

## 主要分支以及打标签规则
* master：存放 AGit 工具以及补丁的分支，**打标签规则：agit-x.x.x-y.y.y，其中 x 为 Git 的版本，y 为 AGit 版本**
* agit-master：将我们补丁打到 Git 源码的分支，方便大家快速本地编译和调试，**打标规则：vx.x.x-agit-y.y.y，其中 x 为 Git 的版本，y 为 AGit 版本**

## 已经发布的特性分支
### topic/0010-github-action
说明：
* 本特性对 GitHub Action 进行定制，减少在不必要的平台（Windows、macOS）上的构建，以节省费用
* 安装必要的依赖文件，例如在 macOS 上安装 openssl
* 设置 README 中的编译徽章，从原来指向 git/git 项目，到指向 gotgit/private-git 项目
### topic/0020-refs-txn-hook
说明：
* 为 Git 的引用更新增加前置和后置钩子，实现仓库加锁、更新仓库最后更新时间、刷新仓库 checksum 的功能
* TODO: 考虑使用 Git 最新的 reference-transactio 钩子实现上述功能
### topic/0030-black-hole
说明：
* 黑洞克隆模式：提供 git fetch、git pull 时本地不落盘，用于 git 压力测试
  topic/0040-quiltexport
  说明：
* 新增 git quiltexport 子命令，提供将 Git 提交转换为 quilt 格式补丁功能
### topic/0050-rate-limit
说明：
对 git push/pull 命令根据系统负载进行限速

变更
* 2021/6/8：增加配置变量 agit.loadAvgConnectionLimit、agit.loadavgretry、agit.loadavgsoftlimit、agit.loadavghardlimit、agit.loadavgsleepmin、agit.loadavgsleepmax。利用配置变量控制限流，默认开启限流
### topic/0060-agit-txn
说明：
* 伽利略代理层对 Git push协议扩展，添加事务处理
* 依赖特性：proc-receive 的 receive.procReceiveRefs 配置支持多值
### topic/0070-agit-gc
说明：
* 根据仓库的规模（大小 ）优化 git-gc 实现，避免大仓库全量 gc 耗时。实现原理：根据不同仓库规模，设置不同 pack 包阈值，对超过阈值的 pack 包进行保留操作，避免垃圾回收
* 在仓库清理时，可以通过 Git 配置变量 agit.gc= 关闭此特性
### topic/0080-transparent-data-encryption
说明：
* 仓库加密
### topic/0100-end-of-options
说明
* allow pseudo options after --end-of-options
### topic/0110-not-receive-pack-file-with-large-object
说明：
* 增加 receive.maxInputObjectSize 及 receive.maxInputBlobSize 来拒绝过大的对象
* 增加 receive.largeblobsinfo 用于开启大于code.bigFileThreshold的对象的oid及大小记录
* 增加 receive.treesinfo 及 receive.commitsinfo，用于开启接收的commits及trees对象oid记录
### topic/0120-pre-send-pack-hook
说明：
* 增加pre-send-pack hook支持
### topic/0130-write-packed-refs
说明：
* 通过fetch.writePackedRefs或--write-packed-refs开启特性，在执行仓库更新时，将引用合并写入packed-refs，而不写入松散引用，从而提升效率
### topic/5351-support-streaming-blobs-to-disk
说明：
* 改写原有的unpack-objects过程，对于大于core.bigFileThreshold的blob对象的写入，通过流的方式优化性能
* 该topic分支维护的是内部版本，由于与代码加密特性都存在对object-file.c的修改，内部版本和外部版本存在少量差异
* 该分支未直接参与 agit-releases.sh 的集成，通过 topic/0110-not-receive-pack-file-with-large-object 将特性引入
### topic/0173-midx-fixup-deleting-packfile
说明：
*解决几何打包时（ repack -d  --geometric=<factor> ），可能会误删除有用 packfile 的问题
### topic/5583-support-read-netrc-file-from-a-specific-path
说明：  
Support setting the GIT_CURL_NETRC_FILE environment variable to provide
the path (absolute or relative) to the netrc file that curl should use

Although the existing http.c code already support reading of netrc file,
it only supports reading from the root path, because there is no option
to set the CURLOPT_NETRC_FILE which can provide the path to cURL.

At the same time, $HTTPD_HOST is extracted separately so that the
environment variables of httpd host can be used in other test cases.
### topic/0999-agit-version
说明：
* agit-version: 用以维护 agit 版本号（目前不需要我们自行编辑了，patchwork 会自动生成）
* agit-changes：维护 agit 升级日志（目前不需要我们编辑了，已经放到了 master 上并更名成了 CHANGES.md）
* agit-release.sh：agit 分支集成脚本。注意当分支名称、数量有变动时，要更新此脚本（已经弃用了，目前使用 patchwork 工具来生成）

## 开发中的特性
### topic/0090-blame-tree
说明：
* blame-tree：查询指定目录下文件的最新提交记录
* 增加 git-blame-tree 命令
* TODO：本定性一个标记为TODO的提交会引发 t4010测试用例执行失败
### topic/0140-no-loop-loose-objects-and-refs
说明：
* 在遍历松散对象时，不再按照00-ff逐个目录遍历，而是通过读取odb目录内容，遍历符合条件的松散对象目录，减少lookup的过程
  topic/0150-expire-outdated-tempfile
  说明：
* 增加 core.tempfileExpire ，默认7天
* 在尝试创建临时文件数，若目标文件已存在且超过失效时间，会先删除再重新创建，而不是直接报错退出
### topic/0160-auto-gc-if-too-many-loose-refs
说明：
* 增加 gc.autoLooseRefsLimit，默认50
* 当松散引用数大于给定限制时，也会触发自动gc，从而将松散引用打包

## 已经退役的特性
* 0010-git-bundle：已经合入上游

## patchwork 工具使用简述
### export-patches 子命令常用参数
* 不加任何参数：会读取当前目录的中 `GIT-VERSION`，`PATCH-VERSION` 和 `topic.txt` 文件来生成补丁
* `--patch` 参数：可以指定要执行的目录
* `--patches` 参数：可以将生成好的补丁放到指定目录，注：如果指定的目录不为空，patchwork 会给予相应提示并退出
* `--use-remote` 参数：忽略所有本地的 topic 分支，全部参考 remote 的分支
* `--use-local` 参数：当本地有 topic 特性分支，则会优先使用（包括本地已经修改，并且本地与远程有差异情况下），如果本地没有，则会使用远程的分支
* `--remote-name` 参数：指定需要使用的远程名称，如果不指定，程序会默认读取当前分支跟踪的远程名，例如：`origin`
* `--git-version` 参数：指定 Git 的版本，优先级大于读取 `GIT-VERSION` 文件
* `--agit-version` 参数：指定 AGit 的版本，优先级大于读取 `PATCH-VERSION` 文件
### apply-patches 子命令常用参数
* `--patch` 参数：可以指定要执行的目录
* `--git-version` 参数：指定 Git 的版本，优先级大于读取 `GIT-VERSION` 文件
* `--agit-version` 参数：指定 AGit 的版本，优先级大于读取 `PATCH-VERSION` 文件
* `--apply-to` 参数：指定要应用补丁的仓库，这个目录必须是 Git 仓库，并且包含设置好的 Git 版本标签
* `--patches` 参数：指定补丁目录，如果不指定，则会默认使用本地的 `patches` 目录