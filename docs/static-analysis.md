English | [中文](./static-analysis.zh.md)

# Static Analysis

Flux Core is analysed with [Slither](https://github.com/crytic/slither). The analysis is part of CI
and is reproducible locally.

## Toolchain

| Item | Value |
|---|---|
| Slither | `0.11.6` (CI installs the latest `slither-analyzer`) |
| Foundry | `1.8.5` |
| Solc | `0.8.26` |
| Scope | `src/` (dependencies, tests and scripts filtered out) |
| Config | [`slither.config.json`](../slither.config.json) |

## Run

```bash
python3 -m venv .venv
.venv/bin/pip install slither-analyzer

# Full report, fails on medium or higher findings
SLITHER_BIN=.venv/bin/slither bash scripts/run-slither.sh

# Or directly
slither . --config-file slither.config.json --fail-medium
```

CI runs the same command from `.github/workflows/contracts.yml`.

## Baseline and fixes

The first run reported 130 findings. The following issues were fixed in the contracts:

| Finding | Location | Fix |
|---|---|---|
| State written after an external call (`reentrancy-eth` / `reentrancy-no-eth`) | `GenesisAuction.claimCreditBatch` | Refund and `claimed` state are set before `credits.issueBatch` and the ETH send (strict CEI) |
| State written after external calls (`reentrancy-benign`) | `GenesisVault.removeGenesis` | `active` is cleared before claims; the function is `nonReentrant` |
| Unchecked ERC-20 transfer | `UniswapV2LiquidityAdapter` | Replaced raw `transferFrom`/`approve` with `SafeERC20` (`safeTransferFrom` / `forceApprove`) |
| Divide before multiply | `FluxNativePair`, `FluxSwapRouter` | Fee factor kept in the numerator, matching preview and execution exactly |
| NFT burn return ignored | `ConversionEngine.nftToFT` | Burned asset id and Genesis flag are validated against cached values |
| Zero-address recipients | `ProtocolVault`, `FluxSwapRouter`, `FluxNativePair`, `FluxAccount` | Constructors/setters and `execute` reject `address(0)` |
| Redundant statement | `UniswapV4LiquidityMigrator` | Removed the no-op `minLiquidity;` expression and documented the interface contract |

After these fixes Slither reports **no High or Medium findings**. The remaining 85 results are Low or
Informational.

## Documented exclusions

The following detectors are excluded in [`slither.config.json`](../slither.config.json) because the
patterns are intentional. Each exclusion has a matching note in
[security.md](./security.md).

| Detector | Why it is excluded |
|---|---|
| `arbitrary-send-eth` | Payouts are role-gated and the recipient is the caller, bidder, registered Genesis account or configured treasury. See `FeeEngine`, `ProtocolVault`, `RewardVault`, `BalanceVault`, `LiquidityVault`, `GenesisAuction`, `HoldETHStrategy`. |
| `weak-prng` | Trait randomness is visual only, mixes a pluggable provider and is documented as non-financial. Use Chainlink VRF for valuable rarity. |
| `incorrect-equality` | Exact comparisons are intentional: zero delta, zero credits, zero block number and epoch rollover. |
| `locked-ether` | Only the two test doubles (`MockLiquidityAdapter`, `MockUniswapV4Migrator`) hold ETH without a withdrawal path; they are not for production. |
| `uninitialized-local` | Solidity zero-initialises these locals; they are assigned before use. |
| `unused-return` | Remaining cases are interface return values (`prepareRandom`, `addLiquidityETH`, `config`) that are intentionally not needed on-chain. The NFT burn return is validated. |

## Remaining findings

The Low/Informational output includes:

- `low-level-calls` — native ETH transfers use `call` with success checks.
- `reentrancy-events` — events emitted after external calls; state is already settled.
- `timestamp` — auction schedule, epoch and LP deadlines are time-based by design.
- `calls-loop` — reward settlement iterates registered assets; the set is admin-controlled.
- `costly-loop`, `cache-array-length` — bidder iteration; arrays are bounded by gas and auction size.
- `missing-zero-check` — non-critical optional addresses (VRF coordinator, settlement adapters) allow
  zero by design.
- `missing-inheritance`, `naming-convention`, `shadowing-local`, `cyclomatic-complexity`,
  `redundant-statements` — style/informational.

## Interpreting the result

Static analysis is not a substitute for a manual audit or a formal specification. The most important
residual risks are economic and operational: auction demand, admin key management, external
integration configuration and the non-upgradeable design. See [security.md](./security.md).

Chinese version: [static-analysis.zh.md](./static-analysis.zh.md).
