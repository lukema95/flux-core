[English](./faq.md) | 中文

# 常见问题

## A. 产品与机制

### 1. 资产单元究竟是什么？

一种记账单位，代表 10,000 个固定协议资产之一。一个单元要么是：

- 一个 ERC-721 NFT，或
- 10,000 FLUX（一个 FT 头寸）。

它不能同时是两者；转换引擎会在两种形态之间移动它。

### 2. 为什么是 10,000 个单元，且每个单元 10,000 FLUX？

协议固定 10,000 个资产单元，并定义 `1 Unit = 10,000 FLUX`，因此完全稀释后的 FLUX 供应量为 100,000,000，且 `flux.totalSupply / 10,000` 始终等于 FT 单元数。

### 3. 什么是 Credit？

Credit 是 Genesis 拍卖中售出的、对某一个资产单元的具现化前索取权。Credit 持有者可以在 Genesis NFT 和 FT 头寸之间选择。Credit 不能作为 ERC-20 转让；它们由 `ConversionEngine` 消费。

### 4. 为什么我会选择 Genesis NFT 而不是 FT？

Genesis NFT 通过 `GenesisVault` 获得协议奖励的永久按比例份额，并可以拥有一个 ERC-6551 账户。FT 头寸可立即流通且可转让，但没有 Genesis 奖励权益。

### 5. Genesis NFT 销毁后还能重新创建吗？

不能。`nftToFT` 会销毁 Genesis，该资产将永久变为 FT。之后的 `ftToNFT` 始终铸造普通 NFT（绝不会是 Genesis）。这是协议不变量之一。

## B. 拍卖

### 6. CCA 出清如何工作？

竞标者提交预算和最高价。系统会在每个不同的最高价上计算需求；出清价格是需求足以覆盖已释放批次的最高价格。分配按比例进行；如果舍入导致 Credit 未分配，则通过确定性的余数循环处理。

### 7. 什么时候可以取消出价？

仅在拍卖进行中、结束之前，且该出价尚未获得任何分配时。取消会退还全部剩余预算。

### 8. 如果拍卖认购不足会怎样？

如果总需求无法覆盖 5,000 个 Credit，`finalize` 会以 `AuctionUndersubscribed` 回滚。拍卖保持进行状态；只有在状态允许时，管理员才能通过创建新时间表来延长它（实际上，需要在最终确认前重新部署或重新启动）。

### 9. 可以分多笔交易领取 Credit 吗？

可以。`claimCreditBatch(maxCredits)` 每次调用最多铸造 `maxCredits` 个（默认领取辅助函数的上限为 200），最后一次调用还会支付 ETH 退款并将该出价标记为已结算。

## C. 转换与费用

### 10. 谁可以转换？

任何拥有 Credit 或 NFT 并支付精确报价费用的人。`preview(ftToNft)` 返回当前的 `{fee, reward}`；如果 `msg.value` 与费用不一致，交易会回滚。

### 11. 费用如何计算？

`BalanceEngine` 计算 FT 占比。如果转换方向会使该占比进一步偏离 30–40% 的目标区间，则收取最高 `maxFee`（默认 0.01 ETH）的费用。相反方向可以从 `BalanceVault` 获得奖励，金额受其每日预算限制。

### 12. 费用去了哪里？

`FeeEngine` 会拆分费用：30% 流动性、25% Genesis 奖励、25% 平衡/转换奖励以及 20% 协议资金库（默认值）。拆分比例可由管理员配置。

### 13. 金库为空时费用会怎样？

费用仍会收取；奖励部分为零，因为 `rewardQuoteBps` 作用于可用预算。奖励预算为空不会退款。

## D. 奖励与账户

### 14. 奖励存放在哪里？

存放在 `RewardVault` 中，按资产记为负债。`GenesisVault` 跟踪 `accRewardPerGenesis[asset]` 和每个 Genesis 的 `rewardDebt`。

### 15. 如何领取奖励？

`claim(tokenId, asset)` 领取一种资产；`claimAllRegistered(tokenId)` 领取所有已启用的资产。付款进入 NFT 的 ERC-6551 账户，而不是直接给所有者，因此该账户可以持有多种资产，并在销毁时以原子方式划转。

### 16. Genesis 销毁时会发生什么？

`removeGenesis` 会停用 Genesis，并将全部待领奖励支付到 TBA；随后 `AccountManager.settleBeforeBurn` 会将每个已启用的注册资产划转给所有者；之后才会销毁 NFT。Genesis 奖励权益会被永久销毁。

## E. 运维

### 17. 哪些合约可以暂停？

`ConversionEngine`（由 `PAUSER_ROLE` 控制）和 `RewardStrategyManager`（由 `DEFAULT_ADMIN_ROLE` 控制）。拍卖领取、费用分配和金库提现仍然可用。

### 18. 有升级路径吗？

没有。合约不可变。出现缺陷需要部署新合约，并通过协调流程迁移状态。

### 19. 可以在主网部署模拟合约吗？

不可以。`MockLiquidityAdapter`、`MockUniswapV4Migrator`、`MockUniswapV2Migrator`、`MockRandomProvider` 和 `SyncVRFRandomProvider` 都是测试替身。请使用生产适配器和 VRF 提供者。

### 20. 如何运行测试套件和覆盖率？

```bash
forge test
forge coverage --report summary --ir-minimum
bash scripts/check-coverage.sh
```

覆盖率阈值为 `src/` 代码行的 98%；当前测试套件覆盖率为 98.82%。

英文版本：[faq.md](./faq.md)。
