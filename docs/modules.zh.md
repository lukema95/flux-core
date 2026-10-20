[English](./modules.md) | 中文

# 模块设计

按 **职责 / 关键接口 / 权限 / 备注** 组织。所有路径均相对于 `src/`。

## 1. 核心

### AssetRegistry (`core/AssetRegistry.sol`)

- **职责** — 全部 10,000 个资产单元的规范状态、各状态计数器与受保护的状态转换。
- **关键接口** — `initializeGenesis(creditUnits)`、`transition(assetId, expected, next, tokenId, genesis)`、`asset(assetId)`、`stateCount(state)`、`accountedUnits()`、`nftUnits()`。
- **权限** — `DEFAULT_ADMIN_ROLE` 负责初始化；`CONTROLLER_ROLE` 负责状态转换。
- **备注** — 未触碰的 id 采用惰性处理：id `1..initialCreditUnits` 为 `Credit`，其余为 `FT`。`transition` 会拒绝预期状态不匹配、非 Credit 的 Genesis 创建以及 Genesis→NFT。

### ConversionEngine (`core/ConversionEngine.sol`)

- **职责** — 唯一能改变资产形态的入口：Credit → Genesis NFT、Credit → FT、NFT → FT 以及 FT → NFT。同时处理动态费用和奖励的支付。
- **关键接口** — `materializeGenesisNFT(assetId, seed)`、`materializeFT(assetId)`、`nftToFT(tokenId)`（可接收 ETH）、`ftToNFT(seed)`（可接收 ETH）、`preview(ftToNft)`。
- **权限** — `PAUSER_ROLE` 可暂停；`DEFAULT_ADMIN_ROLE` 配置该角色。
- **备注** — 每次变更都应用 `whenNotPaused` + `nonReentrant`；FT 资产通过 `_queueFT` / `_popFT` 按 FIFO/LIFO 排队；`_popFT` 在必要时回退为惰性铸造未触碰的 FT id；NFT 销毁返回值会与缓存的资产 id 和 Genesis 标志进行校验。

### CreditManager (`core/CreditManager.sol`)

- **职责** — 与 ERC-6551 无关的 Credit 所有权账本，用于具现化之前。
- **关键接口** — `issue`、`issueBatch`、`consume`、`creditOwner(assetId)`、`balanceOf`。
- **权限** — `ISSUER_ROLE` 负责发行（拍卖）；`CONSUMER_ROLE` 负责消费（转换引擎）。
- **备注** — 每个 Credit 只能被消费一次；`issueBatch` 每次最多铸造 `DEFAULT_CLAIM_BATCH` 个，以限制 gas。

### FluxToken (`token/FluxToken.sol`)

- **职责** — 带 Permit 和硬性供应上限的 ERC-20。
- **关键接口** — `mint`、`burnFrom`、`UNIT()`、`MAX_SUPPLY()`。
- **权限** — `MINTER_ROLE`、`BURNER_ROLE`。
- **备注** — 最大供应量为 100,000,000 FLUX，恰好等于 10,000 × 10,000。

### DynamicNFT (`token/DynamicNFT.sol`)

- **职责** — 携带 `assetId`、`genesis` 和已冻结 trait 种子的 ERC-721。
- **关键接口** — `mintAsset`、`burnAsset`、`assetOf`、`isGenesis`、`tokenURI`、`setRenderer`。
- **权限** — `MINTER_ROLE`、`BURNER_ROLE`；管理员可更换渲染器。
- **备注** — `burnAsset` 在 `_burn` 之前清除 `alive`，因此代币无法复活，且已销毁 id 的 `tokenURI` 会回滚。

## 2. Trait 层

| 合约 | 职责 | 权限 |
|---|---|---|
| `TraitStorage` | 为每个已分配的资产 id 存储一份 `TraitData` | `GENERATOR_ROLE` 设置/释放 |
| `TraitGenerator` | 请求/消费随机数，并将种子转换为 8 个 trait | `CALLER_ROLE`（`ConversionEngine`） |
| `TraitRenderer` | 根据 trait 组合 SVG 与 data-URI 元数据 | 仅视图 |
| `FrogBodyRenderer` | 48×48 的身体/背景/配饰图层 | 仅视图 |
| `FrogFaceRenderer` | 眼睛与嘴巴图层 | 仅视图 |
| `FrogHeadRenderer` | 帽子/头发/头部图层 | 仅视图 |

随机数通过 `prepareRandom` 准备，并由 `generate` 消费。提供者是可插拔的（`SyncVRFRandomProvider`、`ChainlinkVRFRandomProvider`、`MockRandomProvider`）。最终种子混合了提供者熵、资产 id、代币 id、用户种子、所有者、链 id、区块号、`prevrandao`、前一个区块哈希以及生成器地址。NFT 销毁时会删除 trait，并在下一次 NFT 铸造时重新生成。

## 3. 账户层（ERC-6551 风格）

| 合约 | 职责 | 权限 |
|---|---|---|
| `ERC6551Registry` | 确定性账户创建、标准接口查询 | `admin` 管理 manager/implementation |
| `FluxAccount` | 所有者执行、资产划转，所有者由 NFT 推导 | `owner()` 执行；`manager` 划转 |
| `AccountManager` | 确保账户存在，并在销毁前结算所有已启用的奖励资产 | `SETTLEMENT_ROLE` |

`FluxAccount.owner()` 读取 `IERC721(nft).ownerOf(tokenId)`，并在销毁后返回 `address(0)`。`protocolSweep` 将某一资产的全部余额转给接收方；`AccountManager` 遍历已注册资产，并为每个资产发出一个事件。

## 4. Genesis 层

### GenesisAuction (`genesis/GenesisAuction.sol`)

- **职责** — 带预算 + 最高价出价、检查点、按比例分配、退款、Credit 领取和 LP 引导的连续统一价格 Credit 拍卖。
- **关键接口** — `createAuction`、`bid`、`cancelBid`、`checkpoint`、`finalize`、`claimCredit`、`claimCreditBatch`、`clearingPricePreview`、`bids`。
- **权限** — `DEFAULT_ADMIN_ROLE` 创建/最终确认；拍卖进行期间任何人都可以出价。
- **备注** — 5,000 个 Credit 在拍卖期间线性释放；`finalize` 会分配剩余供应量，若需求不足则回滚。领取操作遵循 CEI 顺序、带保护并支持批量。最终确认还会铸造 50,000,000 FLUX、引导流动性，并将头寸注册到 `LiquidityVault`。

### CCAAllocator (`genesis/CCAAllocator.sol`)

- **职责** — 纯库，用于计算最大可出清需求与出清价格，并进行带确定性余数分配的按比例分配。
- **关键接口** — `maxClearable`、`computeClearingPrice`、`allocate`。
- **备注** — 对最高价去重并排序；无存储、无外部调用。

## 5. 经济层

| 合约 | 职责 | 关键权限 |
|---|---|---|
| `FeeEngine` | 将 ETH 拆分为流动性/Genesis/平衡/协议份额 | `DEFAULT_ADMIN_ROLE` 设置拆分；任何人都可分配 |
| `BalanceEngine` | 根据 FT/NFT 比例和金库预算报出费用与奖励 | `DEFAULT_ADMIN_ROLE` 设置参数 |
| `FeeCurve` | 纯方向性费用/奖励计算 | 库 |
| `RewardAssetRegistry` | 奖励资产及结算适配器的允许列表 | `DEFAULT_ADMIN_ROLE` |
| `RewardVault` | 各资产负债、支付与足额支撑检查 | `ACCOUNTANT_ROLE` |
| `GenesisVault` | 活跃 Genesis 集合、按比例累积、领取与移除 | `CONTROLLER_ROLE`、`DEPOSITOR_ROLE` |
| `RewardStrategyManager` | 执行已注册的奖励策略并存入产出 | `EXECUTOR_ROLE`、`DEFAULT_ADMIN_ROLE` |

默认 `FeeSplit` 为 30% 流动性、25% Genesis 奖励、25% 平衡奖励和 20% 协议。`BalanceEngine` 默认值：目标 FT 区间 30–40%，最高费用 0.01 ETH，奖励报价为可用奖励预算的 1%。

## 6. 金库

| 合约 | 职责 | 关键权限 |
|---|---|---|
| `LiquidityVault` | 复投协议流动性；锁定 Genesis 头寸 | `LP_MANAGER_ROLE`、`GENESIS_REGISTRAR_ROLE` |
| `BalanceVault` | 每日奖励预算与 `payReward` | `REWARDER_ROLE` |
| `ProtocolVault` | 持有协议费用并提取给接收方 | `DEFAULT_ADMIN_ROLE` |

`LiquidityVault` 会拒绝目标等于已注册 Genesis 头寸的 `compound` 调用。`BalanceVault` 按 24 小时周期滚动，并将支出上限设为其余额的 `dailyReleaseBps / 10_000`。

## 7. 集成层

| 合约 | 职责 |
|---|---|
| `ChainlinkVRFRandomProvider` | 在协调器允许列表下请求/完成 VRF 风格随机数 |
| `SyncVRFRandomProvider` | 确定性的本地/测试提供者（请求立即返回） |
| `MockRandomProvider` | 用于测试的基于种子的模拟实现 |
| `UniswapV2LiquidityAdapter` | 在 Uniswap V2 上添加并锁定 FLUX/WETH 流动性 |
| `MockLiquidityAdapter` | 记录名义流动性的本地适配器 |
| `UniswapV4LiquidityMigrator` | 将 FLUX + ETH 转发到外部 v4 启动器 |
| `MockUniswapV4Migrator` | 本地 v4 风格头寸模拟 |
| `FluxAMMFactory` | 每个代币一个原生 ETH 交易对 |
| `FluxNativePair` | 最小化 x·y=k 池，手续费 0.3% |
| `FluxSwapRouter` | 面向用户的兑换、协议费用收取与预览 |
| `MockUniswapV2Migrator` | 创建 `FluxNativePair` 并为其注资，用于演示 |
| `HoldETHStrategy` | 默认奖励策略：持有原生 ETH |

## 8. 角色矩阵

| 角色 | 授予对象 | 权限 |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | 部署者，之后为 `PROTOCOL_ADMIN` | 角色管理、配置，以及在适用情况下暂停 |
| `CONTROLLER_ROLE`（注册表） | `ConversionEngine` | 资产状态转换 |
| `CONTROLLER_ROLE`（GenesisVault） | `ConversionEngine` | 添加/移除 Genesis |
| `DEPOSITOR_ROLE`（GenesisVault） | `RewardStrategyManager`、部署者 | 存入奖励 |
| `ISSUER_ROLE` / `CONSUMER_ROLE` | `GenesisAuction` / `ConversionEngine` | 发行和消费 Credit |
| `MINTER_ROLE` / `BURNER_ROLE` | `ConversionEngine`、`GenesisAuction` | 铸造/销毁 FLUX 和 NFT |
| `PAUSER_ROLE` | 管理员 | 暂停/恢复转换 |
| `LP_MANAGER_ROLE` | 管理员/运营者 | 复投流动性 |
| `GENESIS_REGISTRAR_ROLE` | `GenesisAuction` | 注册已锁定的 Genesis 头寸 |
| `REWARDER_ROLE`（BalanceVault） | `ConversionEngine` | 支付转换奖励 |
| `ACCOUNTANT_ROLE`（RewardVault） | `GenesisVault` | 增加负债并支付奖励 |
| `SETTLEMENT_ROLE`（AccountManager） | `ConversionEngine` | 在 Genesis 销毁前结算 |
| `EXECUTOR_ROLE`（RewardStrategyManager） | `FeeEngine`、运营者 | 执行策略 |
| `CALLER_ROLE`（TraitGenerator） | `ConversionEngine` | 生成/释放 trait |

英文版本：[modules.md](./modules.md)。
