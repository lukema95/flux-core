[English](./README.md) | 中文

# Flux Core

Flux 是一种双形态 NFT/FT 资产协议。每个资产单元既可以作为 ERC-721 NFT 存在，也可以作为
10,000 枚可互换的 FLUX 代币存在，协议将资产单元总量固定为 10,000 个。

本仓库仅包含合约层：Solidity 源码、Foundry 测试、部署与交互脚本。

[![contracts](https://github.com/lukema95/flux-core/actions/workflows/contracts.yml/badge.svg)](https://github.com/lukema95/flux-core/actions/workflows/contracts.yml)
[![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)
[![foundry](https://img.shields.io/badge/foundry-v1.8.5-informational)](https://book.getfoundry.sh/)

> **状态：** 未经审计的研究级代码。在完成独立审计之前，只能部署到测试网。Trait 随机性仅用于视觉，
> 并非财务随机性的来源。

## 核心设计

- **固定供应、两种形态** —— 10,000 个资产单元。一个单元要么是一个 NFT，要么是 10,000 枚 FLUX。
- **Genesis CCA** —— 5,000 个 Credit 通过一场连续统一价格拍卖售出，拍卖为每个竞拍者设定了
  预算与最高价；其余 5,000 个单元用于引导 FLUX/ETH 流动性。
- **唯一转换入口** —— `ConversionEngine` 是唯一能够在 Credit、Genesis NFT、NFT 与 FT 状态之间
  移动资产的合约。
- **惰性状态** —— `AssetRegistry` 只存储真正发生过状态转换的资产；未被触及的 id 由初始的
  Credit/FT 划分推导得出。
- **链上艺术** —— `DynamicNFT` 的元数据与 48×48 SVG 由 Trait 渲染器合约生成；无需 IPFS 或
  外部服务器。
- **ERC-6551 账户** —— 每个 Genesis NFT 都可以拥有一个确定性的代币绑定账户，用于持有奖励资产，
  并在 Genesis 被销毁时原子地归集其中的资产。
- **拉取式奖励** —— `RewardVault` 按资产记录负债，`GenesisVault` 将其按比例分配给活跃的
  Genesis NFT。
- **费用引擎** —— 交易费用与转换费用被拆分到流动性、Genesis 奖励、余额金库和协议国库。
- **可插拔集成** —— VRF 提供方、Uniswap V2 流动性、Uniswap V4 迁移器以及 Flux 原生 AMM 都是
  封装在小型接口之后的适配器。

## 合约

| 合约 | 职责 |
|---|---|
| `core/AssetRegistry` | 权威的资产状态、总量与受保护的状态转换 |
| `core/ConversionEngine` | Credit → Genesis NFT/FT、NFT ↔ FT、费用支付 |
| `core/CreditManager` | 拍卖与转换所使用的 Credit 所有权账本 |
| `token/FluxToken` | 带 Permit、供应量上限、角色门控铸造/销毁的 ERC-20 |
| `token/DynamicNFT` | 携带 asset id、Genesis 标志与 Trait 种子的 ERC-721 |
| `trait/*` | Trait 存储、随机性准备与完全链上的 SVG 元数据 |
| `account/*` | ERC-6551 注册表、代币绑定账户与销毁结算 |
| `genesis/GenesisAuction` | 连续 CCA 拍卖、Credit 领取与 LP 引导 |
| `genesis/CCAAllocator` | 纯清算价格与按比例分配库 |
| `economic/FeeEngine` | 费用拆分与向各金库、策略的分发 |
| `economic/BalanceEngine`, `FeeCurve` | 围绕目标 FT/NFT 区间的动态费用/奖励曲线 |
| `economic/RewardAssetRegistry`, `RewardVault`, `GenesisVault` | 多资产奖励记账与领取 |
| `economic/RewardStrategyManager`, `strategy/HoldETHStrategy` | 可插拔奖励策略执行 |
| `vault/LiquidityVault`, `BalanceVault`, `ProtocolVault` | 流动性复投、奖励预算与国库 |
| `integration/*` | Chainlink VRF、Uniswap V2/V4 适配器、模拟迁移器与 Flux AMM |
| `interfaces/*` | 共享接口与 Uniswap V2 类型定义 |

各合约的详细信息与权限见 [docs/modules.zh.md](./docs/modules.zh.md)。

## 快速开始

前置要求：

- [Foundry](https://book.getfoundry.sh/getting-started/installation) **v1.8.5**（CI 固定的版本）
- `solc 0.8.26`（在 `foundry.toml` 中固定）
- 仅 Slither 与覆盖率脚本需要 Python 3.10+
- 仅在使用 npm 脚本别名时需要 Node.js 20+

```bash
git clone git@github.com:lukema95/flux-core.git
cd flux-core
git submodule update --init lib/forge-std lib/openzeppelin-contracts

forge build
forge test                     # 85 tests
bash scripts/check-coverage.sh # line coverage >= 98%
```

只需要这两个顶层子模块。除非你需要 OpenZeppelin 的测试子模块，否则不要递归克隆 OpenZeppelin；
合约仅依赖 `lib/forge-std` 和 `lib/openzeppelin-contracts`。

## 测试与覆盖率

测试套件涵盖单元测试、集成测试、模糊往返测试和不变量测试：

- 85 个测试，100% 通过
- `src/` 的行覆盖率为 **98.82%**（强制阈值为 98%）
- 不变量：资产单元守恒、FLUX 供应量与 FT 单元数量一致、Genesis 权利无法通过 NFT/FT 往返
  重新创建

```bash
forge test -vv
forge coverage --report summary --ir-minimum
COVERAGE_THRESHOLD=98 bash scripts/check-coverage.sh
```

覆盖率仅统计 `src/`，不含测试与脚本。使用 `--ir-minimum` 是为了避免最大的渲染器合约出现
“stack too deep” 错误。

## 静态分析

Slither 已纳入 CI，也可在本地运行：

```bash
python3 -m venv .venv
.venv/bin/pip install slither-analyzer
SLITHER_BIN=.venv/bin/slither bash scripts/run-slither.sh
```

报告以及每项排除的理由见 [docs/static-analysis.zh.md](./docs/static-analysis.zh.md)。

## 部署

复制环境变量模板，并填入有余额的部署者私钥和 RPC URL：

```bash
cp .env.example .env
source .env

./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network local --broadcast
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
```

部署地址会写入 `deployments/<chainId>.json`（可通过 `DEPLOYMENTS_DIR` 覆盖目录）。脚本会配置
角色、部署完整系统，并可通过 `PROTOCOL_ADMIN` / `PROTOCOL_TREASURY` 将管理员权限移交给多签。

完整指南——部署顺序、验证、部署后检查清单与网络别名——见
[docs/deployment.zh.md](./docs/deployment.zh.md)。

## 脚本

[`script/`](./script) 中的 Foundry 脚本：

| 脚本 | 入口点 |
|---|---|
| `Deploy.s.sol` | `Deploy` —— 完整协议栈 |
| `StartAuction.s.sol` | `StartAuction` —— 安排 Genesis 拍卖 |
| `AuctionActions.s.sol` | `BidAuction`、`FinalizeAuction`、`ClaimAuctionCredit`、`ClaimAuctionCreditBatch`、`ClaimAuctionCreditAll` |
| `ProtocolActions.s.sol` | `MaterializeGenesisNFT`、`MaterializeFT`、`ConvertNFTToFT`、`ConvertFTToNFT`、`ClaimGenesisRewards`、`DistributeFees` |
| `SwapActions.s.sol` | `SwapETHForFlux`、`SwapFluxForETH` |

`script/flux-forge.sh` 是一个轻量封装：它加载 `.env`，并将 `--network` 映射到 Foundry RPC
别名。示例见 [script/README.zh.md](./script/README.zh.md)。

## 文档

文档索引见 [docs/README.zh.md](./docs/README.zh.md)。

- [架构](./docs/architecture.zh.md) —— 分层、状态模型、部署拓扑
- [模块](./docs/modules.zh.md) —— 职责、接口与角色
- [流程](./docs/flows.zh.md) —— 拍卖、转换、费用、奖励与 AMM 路径
- [部署](./docs/deployment.zh.md) —— 部署到新链
- [安全](./docs/security.zh.md) —— 信任模型、假设与限制
- [静态分析](./docs/static-analysis.zh.md) —— Slither 发现与修复
- [FAQ](./docs/faq.zh.md) —— 常见问题与边界情况
- [CHANGELOG](./CHANGELOG.zh.md) —— 发布历史

英文版本：[README.md](./README.md)。

## 安全

- 尚未进行任何第三方审计。
- Genesis 的 Trait 随机性在设计上就是伪随机的，可能受到区块生产者的影响。如果 Trait 稀有度
  具有经济价值，请使用 VRF 提供方。
- 协议没有可升级代理；出现 bug 需要迁移。暂停权限与管理员角色应由多签/时间锁持有。
- 不要为漏洞创建公开 issue；请遵循 [SECURITY.zh.md](./SECURITY.zh.md)。

## 贡献

环境搭建、本地检查、提交约定与拉取请求检查清单见 [CONTRIBUTING.zh.md](./CONTRIBUTING.zh.md)。
参与贡献即表示你同意遵守[行为准则](./CODE_OF_CONDUCT.zh.md)。

## 许可证

Flux Core 以 [MIT License](./LICENSE) 发布。合约带有 `SPDX-License-Identifier: MIT` 头。
