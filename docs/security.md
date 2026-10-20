English | [中文](./security.zh.md)

# Security Model

This document describes who can do what, where funds live, which assumptions the code makes and
which known limitations remain. It complements [SECURITY.md](../SECURITY.md), which explains how to
report an issue.

## Status

- **Not audited.** No third-party audit has been completed.
- Contracts are immutable; there is no upgrade proxy. A defect requires a migration.
- Trait randomness is intended for visual generation, not for financial randomness.
- Production deployments should use a multisig or timelock for all admin roles.

## Actors and powers

| Actor | Is | Can |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` holder | Deployer, then `PROTOCOL_ADMIN` (multisig/timelock) | Configure parameters, grant/revoke roles, pause where supported |
| `ConversionEngine` | Contract | Transition Assets, mint/burn FLUX and NFTs, settle Genesis burns |
| `GenesisAuction` | Contract | Issue Credits, mint FLUX for LP bootstrap, register the Genesis position |
| Bidder | Any account | Bid, cancel before allocation, claim Credits and refunds |
| Genesis NFT owner | Any account | Claim rewards, convert NFT → FT, execute its TBA |
| `RewardStrategyManager` executor | `FeeEngine` or operator | Execute strategies and deposit the output |
| `ProtocolVault.recipient` | Treasury | Receive protocol fees via `withdraw` |

There is no allowlist for bidding or conversion. The auction is the only way Credits enter
circulation.

## Access control

Roles are standard OpenZeppelin `AccessControl` roles:

| Domain | Role | Holder |
|---|---|---|
| Registry | `CONTROLLER_ROLE` | `ConversionEngine` |
| Credit | `ISSUER_ROLE` / `CONSUMER_ROLE` | `GenesisAuction` / `ConversionEngine` |
| FLUX | `MINTER_ROLE` / `BURNER_ROLE` | `ConversionEngine`, `GenesisAuction` |
| NFT | `MINTER_ROLE` / `BURNER_ROLE` | `ConversionEngine` |
| Genesis vault | `CONTROLLER_ROLE` / `DEPOSITOR_ROLE` | `ConversionEngine` / `RewardStrategyManager` |
| Reward vault | `ACCOUNTANT_ROLE` | `GenesisVault` |
| Balance vault | `REWARDER_ROLE` | `ConversionEngine` |
| Liquidity vault | `LP_MANAGER_ROLE` / `GENESIS_REGISTRAR_ROLE` | Operator / `GenesisAuction` |
| Account manager | `SETTLEMENT_ROLE` | `ConversionEngine` |
| Trait generator | `CALLER_ROLE` | `ConversionEngine` |
| Conversion | `PAUSER_ROLE` | Admin |
| Reward strategy | `EXECUTOR_ROLE` | `FeeEngine`, operator |

Admin handoff is explicit: `Deploy.s.sol` grants the new admin role, transfers the ERC-6551 registry
admin, then renounces the deployer's admin role. Verify each step on-chain after deployment.

## Funds and accounting

- **ETH** is held by the auction (bids), `FeeEngine` (pending split), `RewardVault` (reward
  liabilities), `BalanceVault` (daily reward budget), `LiquidityVault` (LP budget) and
  `ProtocolVault` (treasury).
- **FLUX** is minted only by `ConversionEngine` and `GenesisAuction`; total supply is capped at
  100,000,000.
- **Reward assets** can be native ETH or ERC-20 tokens registered in `RewardAssetRegistry`.
  `RewardVault.increaseLiability` rejects deposits that are not fully backed.
- **Genesis settlement** claims rewards and sweeps registered assets to the owner before burning the
  NFT. `removeGenesis` deactivates the Genesis and claims before the external calls complete.

## External calls and reentrancy

- All state-changing conversion paths use `nonReentrant`.
- Auction claims and Genesis removal follow checks-effects-interactions ordering; refunds and rewards
  are sent only after the corresponding state is settled.
- Native ETH sends use `call` with an explicit success check and revert on failure.
- ERC-20 transfers use OpenZeppelin `SafeERC20`.
- The Flux AMM computes output with fee factors in the numerator to avoid divide-before-multiply
  precision loss.

## Randomness

`TraitGenerator` mixes provider entropy with asset/token id, user seed, owner, chain id, block
number, `prevrandao`, the previous block hash and the generator address. This is suitable for visual
traits but is **not** resistant to validator or searcher manipulation. Use
`ChainlinkVRFRandomProvider` (or another commit-reveal provider) if trait rarity carries economic
value.

## Known limitations

1. **No upgradeability** — fixing a deployed contract requires a migration and state transfer.
2. **Trait randomness** — block-level entropy can be influenced; see above.
3. **Auction demand** — `finalize` reverts if demand cannot cover 5,000 Credits; the auction must be
   extended/re-run, otherwise bidders can only cancel before allocation.
4. **External integrations are trusted** — the Uniswap V2 router, v4 launcher and VRF coordinator are
   configured by admin and assumed honest. Mock adapters are for testnets only.
5. **Uniswap V4 adapter** — `UniswapV4LiquidityMigrator` forwards funds to an external launcher; the
   launcher, not this contract, enforces pool-specific minimums.
6. **Mocks hold ETH** — `MockLiquidityAdapter` and `MockUniswapV4Migrator` are test doubles and can
   accumulate ETH; never deploy them on mainnet.
7. **Trait storage growth** — every NFT mint writes one trait record; gas grows with collection size
   but is bounded by 10,000 Assets.

## Invariants

The invariant suite (`test/invariant/ProtocolInvariant.t.sol`) checks:

- Asset Units are conserved across all states.
- FLUX supply equals FT units × 10,000.
- A Genesis right cannot be re-created by NFT → FT → NFT round-trips.

## Static analysis

Slither is run in CI over `src/` with dependency and test paths filtered. The current report, fixes
and documented exclusions are in [static-analysis.md](./static-analysis.md).

## Reporting

Do not open a public issue. Follow [SECURITY.md](../SECURITY.md) and include the commit, a
reproduction (Foundry test preferred) and impact assessment.

Chinese version: [security.zh.md](./security.zh.md).
