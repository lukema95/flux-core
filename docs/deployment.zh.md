[English](./deployment.md) | 中文

# 部署指南

本指南介绍如何使用 Foundry 将完整的 Flux Core 技术栈部署到新的 EVM 链。

## 1. 前置条件

- [Foundry](https://book.getfoundry.sh/getting-started/installation) v1.8.5 或更高版本
- 一个有资金的部署者私钥（`PRIVATE_KEY`）
- 目标链的 RPC 端点
- `solc 0.8.26`（由 Foundry 自动安装）

```bash
cp .env.example .env
# edit PRIVATE_KEY, RPC_URL and the network-specific RPC variable
source .env
```

## 2. 部署内容

| 顺序 | 合约 | 构造函数 / 连接配置 |
|---|---|---|
| 1 | `AssetRegistry` | `admin`，然后 `initializeGenesis(5_000)` |
| 2 | `CreditManager`、`FluxToken` | `admin` |
| 3 | `TraitStorage`、`TraitGenerator`、渲染器、`TraitRenderer`、`DynamicNFT` | 渲染器在 NFT 中不可变 |
| 4 | `RewardAssetRegistry`、`RewardVault`、`GenesisVault` | 原生 ETH 注册为奖励资产 |
| 5 | `FluxAccount` 实现、`ERC6551Registry`、`AccountManager` | 管理器在构造后设置 |
| 6 | `BalanceEngine`、`BalanceVault`、`LiquidityVault`、`ProtocolVault` | `ProtocolVault` 接收资金库资金 |
| 7 | 流动性迁移器 + 适配器 | `UNISWAP_V4_MIGRATOR`、`UNISWAP_V2_ROUTER` 或模拟合约 |
| 8 | `FluxAMMFactory`、`FluxSwapRouter` | 仅在使用 Flux AMM 迁移器时 |
| 9 | `RewardStrategyManager`、`FeeEngine` | 默认拆分 30/25/25/20 |
| 10 | `ConversionEngine` | 接收上述所有地址 |
| 11 | `GenesisAuction` | Credit、FLUX、迁移器、流动性金库 |

部署后，脚本会授予所有运营角色；如果 `PROTOCOL_ADMIN != deployer`，还会将所有 `DEFAULT_ADMIN_ROLE` 和 ERC-6551 注册表管理员权限转给 `PROTOCOL_ADMIN`，并放弃部署者的管理员角色。

## 3. 部署

### 本地 Anvil

```bash
anvil
# in another terminal
source .env
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network local --broadcast
```

### 测试网

```bash
source .env
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network bsc --broadcast
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network hyperliquid --broadcast
```

`flux-forge.sh` 会加载 `.env`，并将 `--network` 解析为 `foundry.toml` 中 `[rpc_endpoints]` 的别名。等价的原始命令：

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
```

BSC 通常需要旧式交易：

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url "$BSC_TESTNET_RPC_URL" --broadcast --legacy
```

### 输出

地址会写入 `deployments/<chainId>.json`。设置 `DEPLOYMENTS_DIR` 可更改输出目录（Foundry 的 `fs_permissions` 条目必须包含该目录）。

```json
{
  "AssetRegistry": "0x...",
  "CreditManager": "0x...",
  "FluxToken": "0x...",
  "DynamicNFT": "0x...",
  "ConversionEngine": "0x...",
  "GenesisAuction": "0x..."
}
```

## 4. 环境变量

| 变量 | 用途 |
|---|---|
| `PRIVATE_KEY` | 部署者私钥；切勿提交 |
| `RPC_URL` | 默认/本地 RPC |
| `MONAD_TESTNET_RPC_URL`、`BSC_TESTNET_RPC_URL`、`HYPERLIQUID_TESTNET_RPC_URL`、`BSC_MAINNET_RPC_URL` | 供 `[rpc_endpoints]` 使用的各网络 RPC |
| `PROTOCOL_ADMIN` | 最终管理员（多签/时间锁）；默认为部署者 |
| `PROTOCOL_TREASURY` | `ProtocolVault` 的接收方 |
| `LP_LOCK` | Uniswap V2 LP 锁定地址 |
| `UNISWAP_V2_ROUTER` | 使用 `UniswapV2LiquidityAdapter`；留空则使用模拟适配器 |
| `UNISWAP_V4_MIGRATOR` | 使用 `UniswapV4LiquidityMigrator`；留空则走 Flux AMM/模拟路径 |
| `FLUX_LEGACY_V4_MOCK` | 使用 `MockUniswapV4Migrator` 而非 Flux AMM |
| `FLUX_SWAP_PROTOCOL_FEE_BPS` | Flux AMM 兑换的协议费用（默认 30，即 0.3%） |
| `VRF_COORDINATOR` | 使用 `ChainlinkVRFRandomProvider`；留空则使用 `SyncVRFRandomProvider` |
| `DEPLOYMENTS_DIR` | 输出目录（默认 `deployments`） |
| `ETHERSCAN_API_KEY` | 合约验证 |

## 5. 验证合约

```bash
forge verify-contract \
  --chain bsc_testnet \
  --watch \
  <CONTRACT_ADDRESS> \
  src/genesis/GenesisAuction.sol:GenesisAuction \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" ...)
```

构造函数参数可从部署交易或 `deployments/<chainId>.json` 中恢复。请先验证 `GenesisAuction`、`ConversionEngine`、`FluxToken`、`DynamicNFT` 和 `GenesisVault`；它们是用户交互的公开接口。

## 6. 部署后检查清单

1. 确认 [modules.zh.md](./modules.zh.md#8-角色矩阵) 中的每个角色都指向预期的合约。
2. 在主网使用前，将 `PROTOCOL_ADMIN` 和 `PROTOCOL_TREASURY` 转交给多签/时间锁。
3. 如果希望立即获得转换奖励，请为 `BalanceVault` 和 `RewardVault` 注资。
4. 在存入任何非原生奖励资产之前，先在 `RewardAssetRegistry` 中注册该资产。
5. 使用 `StartAuction.s.sol` 安排 Genesis 拍卖，并核对 `startTime`/`endTime`。
6. 将 `deployments/<chainId>.json` 复制到使用方应用的部署目录。
7. 在测试网上运行一个小型端到端流程：出价 → 最终确认 → 领取 → 具现化 → 转换。

## 7. 以子模块方式使用 Flux Core

使用方仓库可以将本仓库作为 Git 子模块固定在 `lib/flux-core`：

```bash
git submodule update --init --recursive
forge build
```

并使用以下重映射：

```text
flux-core/=lib/flux-core/src/
```

从子模块运行部署脚本，将结果写入应用自己的 `deployments/` 目录：

```bash
./script/flux-forge.sh script lib/flux-core/script/Deploy.s.sol:Deploy --network bsc --broadcast
```

## 8. 故障排查

- **`OutOfFunds`** — 部署者缺少原生代币支付 gas；请先为其充值。
- **`InvalidSchedule`** — `AUCTION_START` 已过去；请选择一个未来的时间戳。
- **`AuctionUndersubscribed`** — 总需求未能覆盖 5,000 个 Credit；请延长拍卖或接受退款路径。
- **`CoreLiquidityLocked`** — `LiquidityVault.compound` 指向了 Genesis 头寸，而该头寸被有意锁定。
- **覆盖率统计时出现 Stack too deep** — 使用 `--ir-minimum`（覆盖率脚本已这样做）。

英文版本：[deployment.md](./deployment.md)。
