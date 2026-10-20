English | [中文](./faq.zh.md)

# FAQ

## A. Product and mechanics

### 1. What exactly is an Asset Unit?

A unit of account representing one of the 10,000 fixed protocol assets. A Unit is either:

- one ERC-721 NFT, or
- 10,000 FLUX (an FT position).

It cannot be both at the same time; the conversion engine moves it between forms.

### 2. Why 10,000 Units and 10,000 FLUX per Unit?

The protocol fixes 10,000 Asset Units and defines `1 Unit = 10,000 FLUX`, so the fully diluted FLUX
supply is 100,000,000 and `flux.totalSupply / 10,000` always equals the number of FT units.

### 3. What is a Credit?

A Credit is the pre-materialization claim on one Asset Unit sold in the Genesis auction. A Credit
holder chooses between a Genesis NFT and an FT position. Credits are not transferable as ERC-20s;
they are consumed by `ConversionEngine`.

### 4. Why would I choose a Genesis NFT instead of FT?

A Genesis NFT earns a permanent pro-rata share of protocol rewards through `GenesisVault` and can own
an ERC-6551 account. An FT position is immediately liquid and transferable but has no Genesis reward
right.

### 5. Can a Genesis NFT be re-created after burning?

No. `nftToFT` burns the Genesis and the Asset becomes FT permanently. A later `ftToNFT` always mints
a normal NFT (never Genesis). This is one of the protocol invariants.

## B. Auction

### 6. How does the CCA clearing work?

Bidders submit a budget and a maximum price. Demand is computed at each distinct max price; the
clearing price is the highest price at which demand covers the released tranche. Allocation is
pro-rata, with a deterministic remainder loop if rounding leaves credits unassigned.

### 7. When can I cancel a bid?

Only while the auction is active, before it ends, and before the bid has received any allocation.
Cancelling refunds the full remaining budget.

### 8. What happens if the auction is undersubscribed?

`finalize` reverts with `AuctionUndersubscribed` if total demand cannot cover 5,000 Credits. The
auction remains active; the admin can extend it by creating a new schedule only if the state allows
it (in practice, re-deploy or restart before finalization).

### 9. Can I claim Credits in several transactions?

Yes. `claimCreditBatch(maxCredits)` mints up to `maxCredits` per call (capped at 200 by the default
claim helper), and the final call also pays the ETH refund and marks the bid settled.

## C. Conversion and fees

### 10. Who can convert?

Anyone who owns the Credit or NFT and pays the exact quoted fee. `preview(ftToNft)` returns the
current `{fee, reward}`; the transaction reverts if `msg.value` differs from the fee.

### 11. How is the fee calculated?

`BalanceEngine` computes the FT share. If converting in the direction that pushes the share further
outside the 30–40% target band, a fee up to `maxFee` (default 0.01 ETH) is charged. The opposite
direction can pay a reward from `BalanceVault`, bounded by its daily budget.

### 12. Where do fees go?

`FeeEngine` splits them: 30% liquidity, 25% Genesis rewards, 25% balance/conversion rewards and 20%
protocol treasury (defaults). The split is configurable by the admin.

### 13. What happens to the fee when the vault is empty?

The fee is still charged; the reward part is zero because `rewardQuoteBps` applies to the available
budget. There is no refund for an empty reward budget.

## D. Rewards and accounts

### 14. Where are rewards held?

In `RewardVault`, accounted as a liability per asset. `GenesisVault` tracks
`accRewardPerGenesis[asset]` and each Genesis's `rewardDebt`.

### 15. How do I claim rewards?

`claim(tokenId, asset)` claims one asset; `claimAllRegistered(tokenId)` claims every enabled asset.
Payouts go to the NFT's ERC-6551 account, not directly to the owner, so the account can hold multiple
assets and be swept atomically on burn.

### 16. What happens on Genesis burn?

`removeGenesis` deactivates the Genesis and claims all pending rewards to the TBA;
`AccountManager.settleBeforeBurn` then sweeps every enabled registered asset to the owner; only then
is the NFT burned. The Genesis reward right is permanently destroyed.

## E. Operations

### 17. Which contracts can be paused?

`ConversionEngine` (by `PAUSER_ROLE`) and `RewardStrategyManager` (by `DEFAULT_ADMIN_ROLE`). Auction
claims, fee distribution and vault withdrawals remain available.

### 18. Is there an upgrade path?

No. Contracts are immutable. A bug requires deploying new contracts and migrating state through a
coordinated process.

### 19. Can I deploy the mocks on mainnet?

No. `MockLiquidityAdapter`, `MockUniswapV4Migrator`, `MockUniswapV2Migrator`,
`MockRandomProvider` and `SyncVRFRandomProvider` are test doubles. Use the production adapters and a
VRF provider.

### 20. How do I run the test suite and coverage?

```bash
forge test
forge coverage --report summary --ir-minimum
bash scripts/check-coverage.sh
```

The coverage threshold is 98% of `src/` lines; the current suite is at 98.82%.

Chinese version: [faq.zh.md](./faq.zh.md).
