[English](./CONTRIBUTING.md) | 中文

# 贡献指南

感谢你改进 Flux Core。本仓库包含合约层。

## 环境搭建

```bash
git clone git@github.com:lukema95/flux-core.git
cd flux-core
git submodule update --init lib/forge-std lib/openzeppelin-contracts

forge build
forge test
```

Foundry **v1.8.5** 是 CI 使用的版本。Solc 在 `foundry.toml` 中固定为 `0.8.26`。

## 本地检查

在提交拉取请求之前运行以下检查：

```bash
forge fmt --check
forge build
forge test -vv
bash scripts/check-coverage.sh     # >= 98% line coverage of src/
bash scripts/check-docs.sh         # every doc has a .zh.md counterpart
SLITHER_BIN=.venv/bin/slither bash scripts/run-slither.sh
```

覆盖率统计使用 `--ir-minimum`；阈值由 `COVERAGE_THRESHOLD` 控制（默认 `98`）。

## 变更准则

- 除非该改动明确属于破坏性变更，否则保持公共 ABI 与存储布局稳定。
- 每个 bug 修复都要补充回归测试。
- 新的外部调用路径优先采用 checks-effects-interactions 模式，并使用 `nonReentrant`。
- 代币转账使用 `SafeERC20`，并校验调用成功。
- 如果没有在 [docs/modules.zh.md](./docs/modules.zh.md) 和
  [docs/security.zh.md](./docs/security.zh.md) 中记录，就不要新增管理员角色。
- 合约采用 MIT 许可；每个新增 Solidity 文件都需要
  `// SPDX-License-Identifier: MIT`。

## 提交风格

使用简短的祈使句主题，可选地添加约定式前缀：

```text
fix: order auction refund state before external calls
feat: add v4 migrator integration tests
docs: document the role handoff in deployment.zh.md
test: cover protocol vault zero-recipient validation
```

当改动较复杂时，在正文中注明受影响的模块。

## 拉取请求

一个拉取请求应包含：

- 变更内容与原因
- 风险/行为变更
- 用于验证的命令
- 当用户可见行为发生变化时，同步更新英文与中文文档
- 不包含密钥、`.env` 文件、私钥或 RPC 凭据

`.github/PULL_REQUEST_TEMPLATE.md` 中的 PR 模板与此清单一致。

## 文档

所有文档均为双语。英文文件使用 `.md`；中文文件使用 `.zh.md`。当你新增或重命名文档时，
请同时添加两个版本。`bash scripts/check-docs.sh` 会强制校验这种配对。

## 安全

切勿为漏洞创建公开 issue。请遵循 [SECURITY.zh.md](./SECURITY.zh.md)。

## 许可证

参与贡献即表示你同意你的贡献按 [MIT License](./LICENSE) 许可，并且你有权提交它。

英文版本：[CONTRIBUTING.md](./CONTRIBUTING.md)。
