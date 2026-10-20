[English](./static-analysis.md) | 中文

# 静态分析

Flux Core 使用 [Slither](https://github.com/crytic/slither) 进行分析。该分析是 CI 的一部分，并可在本地复现。

## 工具链

| 项目 | 值 |
|---|---|
| Slither | `0.11.6`（CI 安装最新的 `slither-analyzer`） |
| Foundry | `1.8.5` |
| Solc | `0.8.26` |
| 范围 | `src/`（已过滤依赖、测试和脚本） |
| 配置 | [`slither.config.json`](../slither.config.json) |

## 运行

```bash
python3 -m venv .venv
.venv/bin/pip install slither-analyzer

# Full report, fails on medium or higher findings
SLITHER_BIN=.venv/bin/slither bash scripts/run-slither.sh

# Or directly
slither . --config-file slither.config.json --fail-medium
```

CI 从 `.github/workflows/contracts.yml` 运行相同的命令。

## 基线与修复

首次运行报告了 130 个发现项。以下问题已在合约中修复：

| 发现项 | 位置 | 修复 |
|---|---|---|
| 外部调用后写入状态（`reentrancy-eth` / `reentrancy-no-eth`） | `GenesisAuction.claimCreditBatch` | 退款与 `claimed` 状态在 `credits.issueBatch` 和 ETH 发送之前设置（严格的 CEI） |
| 外部调用后写入状态（`reentrancy-benign`） | `GenesisVault.removeGenesis` | `active` 在领取前清除；该函数带有 `nonReentrant` |
| 未检查的 ERC-20 转账 | `UniswapV2LiquidityAdapter` | 用 `SafeERC20`（`safeTransferFrom` / `forceApprove`）替换原始的 `transferFrom`/`approve` |
| 先除后乘 | `FluxNativePair`、`FluxSwapRouter` | 将费用因子保留在分子中，使预览与执行完全一致 |
| 忽略 NFT 销毁返回值 | `ConversionEngine.nftToFT` | 销毁的资产 id 和 Genesis 标志会与缓存值校验 |
| 零地址接收方 | `ProtocolVault`、`FluxSwapRouter`、`FluxNativePair`、`FluxAccount` | 构造函数/设置函数和 `execute` 拒绝 `address(0)` |
| 冗余语句 | `UniswapV4LiquidityMigrator` | 移除了无操作的 `minLiquidity;` 表达式，并记录了接口约定 |

修复后，Slither 报告 **没有 High 或 Medium 级别的发现项**。其余 85 个结果为 Low 或 Informational。

## 已记录的排除项

以下检测器在 [`slither.config.json`](../slither.config.json) 中被排除，因为这些模式是有意为之。每个排除项在 [security.zh.md](./security.zh.md) 中都有对应的说明。

| 检测器 | 排除原因 |
|---|---|
| `arbitrary-send-eth` | 付款受角色限制，接收方是调用者、竞标者、已注册的 Genesis 账户或配置的资金库。参见 `FeeEngine`、`ProtocolVault`、`RewardVault`、`BalanceVault`、`LiquidityVault`、`GenesisAuction`、`HoldETHStrategy`。 |
| `weak-prng` | Trait 随机性仅用于视觉，混合可插拔提供者，并已记录为非金融用途。若稀有度有价值，请使用 Chainlink VRF。 |
| `incorrect-equality` | 精确比较是有意为之：零增量、零 Credit、零区块号和 epoch 滚动。 |
| `locked-ether` | 只有两个测试替身（`MockLiquidityAdapter`、`MockUniswapV4Migrator`）持有 ETH 且没有提现路径；它们不用于生产。 |
| `uninitialized-local` | Solidity 会将这些局部变量零初始化；它们在使用前已被赋值。 |
| `unused-return` | 其余情况是接口返回值（`prepareRandom`、`addLiquidityETH`、`config`），链上确实不需要。NFT 销毁返回值会被校验。 |

## 剩余发现项

Low/Informational 输出包括：

- `low-level-calls` — 原生 ETH 转账使用带成功检查的 `call`。
- `reentrancy-events` — 外部调用后发出事件；此时状态已经结算。
- `timestamp` — 拍卖时间表、epoch 和 LP 截止时间按设计基于时间。
- `calls-loop` — 奖励结算会遍历已注册资产；该集合由管理员控制。
- `costly-loop`、`cache-array-length` — 遍历竞标者；数组受 gas 和拍卖规模约束。
- `missing-zero-check` — 非关键的可选地址（VRF 协调器、结算适配器）按设计允许为零。
- `missing-inheritance`、`naming-convention`、`shadowing-local`、`cyclomatic-complexity`、`redundant-statements` — 风格/信息类。

## 结果解读

静态分析不能替代人工审计或形式化规范。最重要的剩余风险是经济与运营层面的：拍卖需求、管理员密钥管理、外部集成配置以及不可升级的设计。参见 [security.zh.md](./security.zh.md)。

英文版本：[static-analysis.md](./static-analysis.md)。
