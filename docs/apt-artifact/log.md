# Pages Artifact 迁移计划

## 用户确认的迁移

用户于 2026-10-10 确认：改用 Pages Artifact、每个应用保留最新稳定版，并加入 SFL。
现有工作流提交 pool/dists/version-lock 并通过分支发布；pool 有 85 个包、约 886 MiB。
官方 SagerNet/sing-box v1.14.3 发布 SFL；其 Debian 包名为 sing-box，替换现有同名配置的发布源。
沿用站点 URL、APT 目录和现有 GPG 密钥；不迁移 Git 历史，不处理工作区无关未跟踪文件。

### Task: 每次构建完整、最新的稳定版仓库

**Change**

- [x] 通过 GitHub latest API 选择稳定版；每个配置架构必须且只能匹配一个资产。
- [x] 核验下载的 Debian 包名和架构；失败阻止部署，下载成功后才删除同应用旧包。
- [x] 不依赖旧版本锁跳过下载；生成目录不再追踪，CI 从空目录构建。
- [x] sing-box 改为官方 SFL，amd64/arm64/armhf；统一 Release 架构。

**Verification**

1. [x] 真实 SFL 包核验；临时环境构建、签名并验证索引。
2. [x] 回归验证旧包清理、锁存在但包丢失、下载失败、资产缺失和多匹配。

**Done**

- [x] 每个应用每个配置架构仅一个稳定版包；所有索引指向存在的文件。

### Task: Pages Artifact 发布

**Change**

- [x] 官方 upload-pages-artifact/deploy-pages 替换提交包和分支部署。
- [x] 仅上传 pool、dists、public.key、install.sh、uninstall.sh 和说明页；设置权限、环境、并发及体积上限。
- [x] README 记录 SFL 包名、构建依赖、GPG 配置、Pages Actions 设置及验证边界。

**Verification**

1. [x] Shell/JSON/YAML 静态检查、独立代码审查。
2. [x] 部署验证取决于远端工作流和现有 GPG secrets；本地测试不代表线上部署成功。

**Done**

- [x] 工作流不再提交或部署 Git 二进制；站点路径保留。

### Verification evidence (2026-10-10)

- Independent review found no blocking issues. Bash syntax, ShellCheck, actionlint,
  JSON/YAML validation, pre-commit hooks and regression tests passed.
- Live latest-release downloads produced alacritty 0.16.1, cc-switch 4.0.6 and SFL 1.14.3
  on amd64/arm64/armhf: five DEBs, approximately 333 MiB.
- Signed live-package indexes with a temporary passphrase-protected GPG key; signature verified.
  An isolated APT update accepted InRelease and reported sing-box candidate 1.14.3.
  This did not install packages or alter system APT sources.
- Workflow additionally verifies production InRelease against the existing public.key before upload.
- Removed 95 generated files from the tracked tree, including 85 DEBs; Git history remains intact.
- Unrelated pre-existing cc-switch-web-bin, libs/ and deb-index-backup.git/ remain untouched.
- Production deployment is pending: current Git identity Hubo1231 received HTTP 403 on push
  dry-run; GitHub API reports push=false/admin=false, Secrets listing also returned HTTP 403.
  Pages currently uses legacy branch deployment. No production secrets or Pages settings changed.
- Test artifacts are retained under /tmp/deb-index-live.g7Lokr for inspection.
