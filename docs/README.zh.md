[English](./README.md) | 中文

# Flux Core 文档

本文档介绍 `src/` 中的合约与 `script/` 中的脚本。`lib/` 下的依赖代码不在范围内。

建议阅读顺序：

1. [architecture.zh.md](./architecture.zh.md) — 一页了解系统：分层、状态模型、不变量
2. [modules.zh.md](./modules.zh.md) — 每个合约的职责、可调用者及其依赖
3. [flows.zh.md](./flows.zh.md) — 拍卖、转换、费用、奖励、销毁和 AMM 调用路径
4. [deployment.zh.md](./deployment.zh.md) — 部署、验证并交接管理员权限
5. [security.zh.md](./security.zh.md) — 信任模型、外部假设和已知限制
6. [static-analysis.zh.md](./static-analysis.zh.md) — Slither 结果、修复和排除项
7. [faq.zh.md](./faq.zh.md) — 常见问题与边界情况
8. [../CHANGELOG.zh.md](../CHANGELOG.zh.md) — 发布历史

## 30 秒概览

Flux 将 10,000 个供应量固定的资产单元转变为一个双边市场：

- 每个单元要么是一个 NFT **或** 10,000 FLUX，二者不可兼得。
- Genesis 通过连续统一价格拍卖出售 5,000 个 Credit，并用拍卖所得和剩余的 5,000 个单元为 FLUX/ETH 注入流动性。
- Credit 持有者可以选择 Genesis NFT（永久奖励份额 + ERC-6551 账户），或可立即流通的 FT 头寸。
- NFT 与 FT 可双向转换；协议根据 FT 占比收取动态费用/发放奖励，并通过四路拆分分配费用。

一句话：**一个供应量固定的资产，具备 NFT/FT 转换引擎、CCA 发行和链上奖励。**

## 源码地图

```text
src/
├── core/          # AssetRegistry, ConversionEngine, CreditManager
├── token/         # FluxToken, DynamicNFT
├── account/       # ERC-6551 registry, FluxAccount, AccountManager
├── genesis/       # GenesisAuction, CCAAllocator
├── trait/         # trait storage/generation and on-chain SVG renderers
├── economic/      # fees, balance curve, reward registry/vault/strategy
├── vault/         # liquidity, balance and protocol vaults
├── strategy/      # reward strategy adapters
├── integration/   # VRF, Uniswap adapters, Flux AMM
└── interfaces/    # shared interfaces
```

## 核心概念

| 主题 | 摘要 |
|---|---|
| 资产单元 | 记账单位。共 10,000 个；每个要么是 NFT，要么是 10,000 FLUX。 |
| Credit | 对 Genesis 拍卖中售出的一个资产单元的索取权。 |
| Genesis NFT | 具现化为 NFT 的 Credit，附带永久奖励份额和 ERC-6551 账户。 |
| FT | 由 1 个资产单元支撑的 10,000 FLUX。同质化且可转让。 |
| 惰性状态 | 未触碰的资产 id 由初始 Credit/FT 划分推导；只有状态转换才会写入存储。 |
| 动态费用 | 当转换方向使 FT 占比偏离 30–40% 时，`BalanceEngine` 会提高费用。 |
| 奖励预算 | `BalanceVault` 每天释放其余额中一个有上限的比例，用于转换奖励。 |

英文版本：[README.md](./README.md)。
