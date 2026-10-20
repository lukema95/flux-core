[English](./security.md) | 中文

# 安全模型

本文档说明谁可以做什么、资金存放在哪里、代码做出了哪些假设，以及仍存在哪些已知限制。它是对 [SECURITY.zh.md](../SECURITY.zh.md) 的补充，后者说明了如何报告问题。

## 状态

- **未经审计。** 尚未完成第三方审计。
- 合约为不可变合约；没有升级代理。修复缺陷需要迁移。
- Trait 随机数仅用于视觉生成，不用于金融随机性。
- 生产部署应为所有管理员角色使用多签或时间锁。

## 参与者与权限

| 参与者 | 身份 | 能力 |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` 持有者 | 部署者，之后为 `PROTOCOL_ADMIN`（多签/时间锁） | 配置参数、授予/撤销角色，并在支持时暂停 |
| `ConversionEngine` | 合约 | 转换资产状态、铸造/销毁 FLUX 与 NFT、结算 Genesis 销毁 |
| `GenesisAuction` | 合约 | 发行 Credit、为 LP 引导铸造 FLUX、注册 Genesis 头寸 |
| 竞标者 | 任意账户 | 出价、在分配前取消、领取 Credit 与退款 |
| Genesis NFT 所有者 | 任意账户 | 领取奖励、将 NFT 转换为 FT、执行其 TBA |
| `RewardStrategyManager` 执行者 | `FeeEngine` 或运营者 | 执行策略并存入产出 |
| `ProtocolVault.recipient` | 资金库 | 通过 `withdraw` 接收协议费用 |

出价和转换均无允许列表。拍卖是 Credit 进入流通的唯一途径。

## 访问控制

角色是标准的 OpenZeppelin `AccessControl` 角色：

| 领域 | 角色 | 持有者 |
|---|---|---|
| 注册表 | `CONTROLLER_ROLE` | `ConversionEngine` |
| Credit | `ISSUER_ROLE` / `CONSUMER_ROLE` | `GenesisAuction` / `ConversionEngine` |
| FLUX | `MINTER_ROLE` / `BURNER_ROLE` | `ConversionEngine`、`GenesisAuction` |
| NFT | `MINTER_ROLE` / `BURNER_ROLE` | `ConversionEngine` |
| Genesis 金库 | `CONTROLLER_ROLE` / `DEPOSITOR_ROLE` | `ConversionEngine` / `RewardStrategyManager` |
| 奖励金库 | `ACCOUNTANT_ROLE` | `GenesisVault` |
| 平衡金库 | `REWARDER_ROLE` | `ConversionEngine` |
| 流动性金库 | `LP_MANAGER_ROLE` / `GENESIS_REGISTRAR_ROLE` | 运营者 / `GenesisAuction` |
| 账户管理器 | `SETTLEMENT_ROLE` | `ConversionEngine` |
| Trait 生成器 | `CALLER_ROLE` | `ConversionEngine` |
| 转换 | `PAUSER_ROLE` | 管理员 |
| 奖励策略 | `EXECUTOR_ROLE` | `FeeEngine`、运营者 |

管理员交接是显式的：`Deploy.s.sol` 先授予新的管理员角色，转移 ERC-6551 注册表管理员权限，然后放弃部署者的管理员角色。部署后请在链上逐步核实。

## 资金与记账

- **ETH** 由拍卖（出价）、`FeeEngine`（待拆分）、`RewardVault`（奖励负债）、`BalanceVault`（每日奖励预算）、`LiquidityVault`（LP 预算）和 `ProtocolVault`（资金库）持有。
- **FLUX** 仅由 `ConversionEngine` 和 `GenesisAuction` 铸造；总供应量上限为 100,000,000。
- **奖励资产** 可以是原生 ETH 或在 `RewardAssetRegistry` 中注册的 ERC-20 代币。`RewardVault.increaseLiability` 会拒绝未足额支撑的存款。
- **Genesis 结算** 会在销毁 NFT 之前领取奖励并将已注册资产划转给所有者。`removeGenesis` 会停用 Genesis 并在外部调用结束前完成领取。

## 外部调用与重入

- 所有改变状态的转换路径都使用 `nonReentrant`。
- 拍卖领取和 Genesis 移除遵循检查-效果-交互顺序；退款和奖励只有在相应状态结算后才会发送。
- 原生 ETH 转账使用 `call`，并显式检查成功与否，失败时回滚。
- ERC-20 转账使用 OpenZeppelin `SafeERC20`。
- Flux AMM 在分子中包含费用因子来计算输出，以避免先除后乘的精度损失。

## 随机性

`TraitGenerator` 将提供者熵与资产/代币 id、用户种子、所有者、链 id、区块号、`prevrandao`、前一个区块哈希以及生成器地址混合。这适用于视觉 trait，但**不能**抵抗验证者或搜索者的操纵。如果 trait 稀有度具有经济价值，请使用 `ChainlinkVRFRandomProvider`（或其他提交-揭示提供者）。

## 已知限制

1. **不可升级** — 修复已部署合约需要迁移和状态转移。
2. **Trait 随机性** — 区块级熵可能被影响；见上文。
3. **拍卖需求** — 如果需求无法覆盖 5,000 个 Credit，`finalize` 会回滚；必须延长/重新运行拍卖，否则竞标者只能在分配前取消。
4. **外部集成受信任** — Uniswap V2 路由器、v4 启动器和 VRF 协调器由管理员配置，并假定其诚实。模拟适配器仅用于测试网。
5. **Uniswap V4 适配器** — `UniswapV4LiquidityMigrator` 将资金转发到外部启动器；由启动器（而非本合约）执行各池特定的最低要求。
6. **模拟合约持有 ETH** — `MockLiquidityAdapter` 和 `MockUniswapV4Migrator` 是测试替身，可能累积 ETH；切勿在主网部署它们。
7. **Trait 存储增长** — 每次 NFT 铸造都会写入一条 trait 记录；gas 随收藏规模增长，但受 10,000 个资产的上限约束。

## 不变量

不变量测试套件（`test/invariant/ProtocolInvariant.t.sol`）检查：

- 资产单元在所有状态间守恒。
- FLUX 供应量等于 FT 单元数 × 10,000。
- Genesis 权益无法通过 NFT → FT → NFT 往返重新创建。

## 静态分析

Slither 在 CI 中对 `src/` 运行，并过滤依赖和测试路径。当前报告、修复和已记录的排除项见 [static-analysis.zh.md](./static-analysis.zh.md)。

## 报告

请勿公开提交 issue。遵循 [SECURITY.zh.md](../SECURITY.zh.md)，并附上提交哈希、复现步骤（优先使用 Foundry 测试）和影响评估。

英文版本：[security.md](./security.md)。
