[English](./CHANGELOG.md) | 中文

# 变更日志

Flux Core 的所有重要变更都记录于此。格式遵循
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，项目遵循
[语义化版本](https://semver.org/spec/v2.0.0.html)。

## [Unreleased]

## [1.0.0] - 2026-10-21

Flux Core 首次发布：一个固定供应量、NFT/FT 双形态的资产协议。

### 新增

- 核心资产状态机：`AssetRegistry`、`ConversionEngine` 与 `CreditManager`，支持惰性状态推导与
  受控状态转换。
- `FluxToken`（ERC-20 + Permit，供应量上限）与 `DynamicNFT`（携带 asset id、Genesis 标志与
  固化 Trait 种子的 ERC-721）。
- 完全链上的 Trait 生成与 SVG 渲染：`TraitStorage`、`TraitGenerator`、`TraitRenderer` 以及
  身体/面部/头部渲染器。
- ERC-6551 风格账户层：`ERC6551Registry`、`FluxAccount` 与 `AccountManager`，提供确定性账户
  与 Genesis 销毁前的原子结算。
- Genesis 发行：`GenesisAuction` 连续统一价格 CCA、`CCAAllocator` 清算/分配库、批量 Credit
  领取、退款与 LP 引导。
- 奖励栈：`RewardAssetRegistry`、`RewardVault`、`GenesisVault` 与
  `RewardStrategyManager`，支持按比例记账与可插拔的 `HoldETHStrategy`。
- 费用栈：`FeeEngine`、`BalanceEngine`、`FeeCurve` 以及流动性/余额/协议金库。
- Flux AMM（`FluxAMMFactory`、`FluxNativePair`、`FluxSwapRouter`），以及 Uniswap V2/V4 与
  VRF 适配器，用于测试网和生产环境接线。
- Foundry 部署与交互脚本：完整协议栈、拍卖生命周期、协议操作与 AMM 兑换。
- 双语文档（英文 + `*.zh.md`），涵盖架构、模块、流程、部署、安全、静态分析与 FAQ。
- MIT 许可证、贡献指南、安全策略、行为准则、维护者文件以及 GitHub issue/PR 模板。
- 用于构建、测试、覆盖率、Slither 与文档语言检查的 CI，以及
  `scripts/check-coverage.sh` 的 98% 行覆盖率门禁。
- 85 个 Foundry 测试：单元、集成、fuzz round-trip 与不变量套件。

### 安全

- 拍卖领取与 Genesis 移除采用严格的 checks-effects-interactions 顺序。
- 代币转账与授权使用 `SafeERC20`；原生 ETH 发送显式检查成功状态。
- AMM 输出计算将费用因子保留在分子中，避免精度损失与溢出风险。
- 校验 NFT 销毁的返回值，并在关键配置路径上检查零地址。
- 在文档所述的排除项下，Slither 未报告 High 或 Medium 问题。
- 未进行第三方审计。参见 [SECURITY.zh.md](./SECURITY.zh.md) 与
  [docs/security.zh.md](./docs/security.zh.md)。

英文版本：[CHANGELOG.md](./CHANGELOG.md)。
