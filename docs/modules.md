English | [中文](./modules.zh.md)

# Module Design

Organized as **responsibility / key interface / permissions / notes**. All paths are relative to
`src/`.

## 1. Core

### AssetRegistry (`core/AssetRegistry.sol`)

- **Responsibility** — canonical state of all 10,000 Asset Units, per-state counters and guarded
  transitions.
- **Key interface** — `initializeGenesis(creditUnits)`, `transition(assetId, expected, next,
  tokenId, genesis)`, `asset(assetId)`, `stateCount(state)`, `accountedUnits()`, `nftUnits()`.
- **Permissions** — `DEFAULT_ADMIN_ROLE` initializes; `CONTROLLER_ROLE` transitions.
- **Notes** — untouched ids are lazy: ids `1..initialCreditUnits` are `Credit`, the rest `FT`.
  `transition` rejects mismatched expected state, non-Credit Genesis creation and Genesis→NFT.

### ConversionEngine (`core/ConversionEngine.sol`)

- **Responsibility** — the only entry point that changes an Asset's form: Credit → Genesis NFT,
  Credit → FT, NFT → FT and FT → NFT. Also pays the dynamic fee and reward.
- **Key interface** — `materializeGenesisNFT(assetId, seed)`, `materializeFT(assetId)`,
  `nftToFT(tokenId)` payable, `ftToNFT(seed)` payable, `preview(ftToNft)`.
- **Permissions** — `PAUSER_ROLE` pauses; `DEFAULT_ADMIN_ROLE` configures the role.
- **Notes** — `whenNotPaused` + `nonReentrant` on every mutation; FT assets are queued FIFO/LIFO via
  `_queueFT` / `_popFT`; `_popFT` falls back to lazily minting untouched FT ids; NFT burn return data
  is validated against the cached asset id and Genesis flag.

### CreditManager (`core/CreditManager.sol`)

- **Responsibility** — ERC-6551-independent ledger of Credit ownership before materialization.
- **Key interface** — `issue`, `issueBatch`, `consume`, `creditOwner(assetId)`, `balanceOf`.
- **Permissions** — `ISSUER_ROLE` issues (auction); `CONSUMER_ROLE` consumes (conversion engine).
- **Notes** — a Credit is consumed exactly once; `issueBatch` mints up to
  `DEFAULT_CLAIM_BATCH` at a time to bound gas.

### FluxToken (`token/FluxToken.sol`)

- **Responsibility** — ERC-20 with Permit and a hard supply cap.
- **Key interface** — `mint`, `burnFrom`, `UNIT()`, `MAX_SUPPLY()`.
- **Permissions** — `MINTER_ROLE`, `BURNER_ROLE`.
- **Notes** — max supply is 100,000,000 FLUX, exactly 10,000 × 10,000.

### DynamicNFT (`token/DynamicNFT.sol`)

- **Responsibility** — ERC-721 that carries `assetId`, `genesis` and the frozen trait seed.
- **Key interface** — `mintAsset`, `burnAsset`, `assetOf`, `isGenesis`, `tokenURI`,
  `setRenderer`.
- **Permissions** — `MINTER_ROLE`, `BURNER_ROLE`; admin can change the renderer.
- **Notes** — `burnAsset` clears `alive` before `_burn`, so the token cannot be resurrected and
  `tokenURI` reverts for burned ids.

## 2. Trait layer

| Contract | Responsibility | Permissions |
|---|---|---|
| `TraitStorage` | Stores one `TraitData` per assigned Asset id | `GENERATOR_ROLE` sets/releases |
| `TraitGenerator` | Requests/consumes randomness and converts a seed into 8 traits | `CALLER_ROLE` (`ConversionEngine`) |
| `TraitRenderer` | Composes SVG and data-URI metadata from traits | view only |
| `FrogBodyRenderer` | 48×48 body/background/accessory layers | view only |
| `FrogFaceRenderer` | Eyes and mouth layers | view only |
| `FrogHeadRenderer` | Hat/hair/head layers | view only |

Randomness is prepared with `prepareRandom` and consumed by `generate`. The provider is pluggable
(`SyncVRFRandomProvider`, `ChainlinkVRFRandomProvider`, `MockRandomProvider`). The final seed mixes
provider entropy, asset id, token id, user seed, owner, chain id, block number, `prevrandao`, the
previous block hash and the generator address. Traits are deleted when an NFT is burned and
regenerated on the next NFT mint.

## 3. Account layer (ERC-6551 style)

| Contract | Responsibility | Permissions |
|---|---|---|
| `ERC6551Registry` | Deterministic account creation, standard interface lookup | `admin` manages manager/implementation |
| `FluxAccount` | Owner execution, asset sweep, owner derived from the NFT | `owner()` executes; `manager` sweeps |
| `AccountManager` | Ensures the account and settles all enabled reward assets before burn | `SETTLEMENT_ROLE` |

`FluxAccount.owner()` reads `IERC721(nft).ownerOf(tokenId)` and returns `address(0)` after burn.
`protocolSweep` transfers the full balance of one asset to the recipient; `AccountManager`
iterates the registered assets and emits one event per asset.

## 4. Genesis layer

### GenesisAuction (`genesis/GenesisAuction.sol`)

- **Responsibility** — continuous uniform-price Credit auction with budget + max-price bids,
  checkpoints, pro-rata allocation, refunds, credit claims and LP bootstrap.
- **Key interface** — `createAuction`, `bid`, `cancelBid`, `checkpoint`, `finalize`,
  `claimCredit`, `claimCreditBatch`, `clearingPricePreview`, `bids`.
- **Permissions** — `DEFAULT_ADMIN_ROLE` creates/finalizes; anyone bids while active.
- **Notes** — 5,000 Credits are released linearly over the auction; `finalize` allocates the
  remaining supply and reverts if demand is insufficient. Claims are CEI-ordered, guarded and
  batched. Finalize mints 50,000,000 FLUX, bootstraps liquidity and registers the position in
  `LiquidityVault`.

### CCAAllocator (`genesis/CCAAllocator.sol`)

- **Responsibility** — pure library for maximum clearable demand, clearing price and pro-rata
  allocation with deterministic remainder distribution.
- **Key interface** — `maxClearable`, `computeClearingPrice`, `allocate`.
- **Notes** — sorted unique max prices; no storage, no external calls.

## 5. Economic layer

| Contract | Responsibility | Key permissions |
|---|---|---|
| `FeeEngine` | Splits ETH into liquidity/genesis/balance/protocol shares | `DEFAULT_ADMIN_ROLE` sets split; anyone distributes |
| `BalanceEngine` | Quotes fee and reward from FT/NFT ratio and vault budget | `DEFAULT_ADMIN_ROLE` sets parameters |
| `FeeCurve` | Pure directional fee/reward math | library |
| `RewardAssetRegistry` | Allowlist of reward assets and settlement adapters | `DEFAULT_ADMIN_ROLE` |
| `RewardVault` | Per-asset liabilities, payouts and backing check | `ACCOUNTANT_ROLE` |
| `GenesisVault` | Active Genesis set, pro-rata accrual, claims and removal | `CONTROLLER_ROLE`, `DEPOSITOR_ROLE` |
| `RewardStrategyManager` | Executes registered reward strategies and deposits output | `EXECUTOR_ROLE`, `DEFAULT_ADMIN_ROLE` |

The default `FeeSplit` is 30% liquidity, 25% Genesis rewards, 25% balance rewards and 20% protocol.
`BalanceEngine` defaults: target FT range 30–40%, max fee 0.01 ETH, reward quote 1% of the available
reward budget.

## 6. Vaults

| Contract | Responsibility | Key permissions |
|---|---|---|
| `LiquidityVault` | Compounds protocol liquidity; locks the Genesis position | `LP_MANAGER_ROLE`, `GENESIS_REGISTRAR_ROLE` |
| `BalanceVault` | Daily reward budget and `payReward` | `REWARDER_ROLE` |
| `ProtocolVault` | Holds protocol fees and withdraws to the recipient | `DEFAULT_ADMIN_ROLE` |

`LiquidityVault` rejects `compound` calls whose target equals the registered Genesis position.
`BalanceVault` rolls a 24-hour epoch and caps spending at `dailyReleaseBps / 10_000` of its balance.

## 7. Integration layer

| Contract | Responsibility |
|---|---|
| `ChainlinkVRFRandomProvider` | Request/fulfill VRF-style randomness with a coordinator allowlist |
| `SyncVRFRandomProvider` | Deterministic local/test provider (request returns immediately) |
| `MockRandomProvider` | Seed-based mock for tests |
| `UniswapV2LiquidityAdapter` | Adds and locks FLUX/WETH liquidity on Uniswap V2 |
| `MockLiquidityAdapter` | Local adapter that records notional liquidity |
| `UniswapV4LiquidityMigrator` | Forwards FLUX + ETH to an external v4 launcher |
| `MockUniswapV4Migrator` | Local v4-style position mock |
| `FluxAMMFactory` | One native-ETH pair per token |
| `FluxNativePair` | Minimal x·y=k pool with a 0.3% fee |
| `FluxSwapRouter` | User-facing swaps, protocol fee collection and previews |
| `MockUniswapV2Migrator` | Creates a `FluxNativePair` and seeds it for demos |
| `HoldETHStrategy` | Default reward strategy: hold native ETH |

## 8. Role matrix

| Role | Granted to | Powers |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | Deployer then `PROTOCOL_ADMIN` | Role management, configuration, pause where applicable |
| `CONTROLLER_ROLE` (registry) | `ConversionEngine` | Asset transitions |
| `CONTROLLER_ROLE` (GenesisVault) | `ConversionEngine` | Add/remove Genesis |
| `DEPOSITOR_ROLE` (GenesisVault) | `RewardStrategyManager`, deployer | Deposit rewards |
| `ISSUER_ROLE` / `CONSUMER_ROLE` | `GenesisAuction` / `ConversionEngine` | Issue and consume Credits |
| `MINTER_ROLE` / `BURNER_ROLE` | `ConversionEngine`, `GenesisAuction` | Mint/burn FLUX and NFTs |
| `PAUSER_ROLE` | Admin | Pause/unpause conversions |
| `LP_MANAGER_ROLE` | Admin/operator | Compound liquidity |
| `GENESIS_REGISTRAR_ROLE` | `GenesisAuction` | Register the locked Genesis position |
| `REWARDER_ROLE` (BalanceVault) | `ConversionEngine` | Pay conversion rewards |
| `ACCOUNTANT_ROLE` (RewardVault) | `GenesisVault` | Increase liabilities and pay rewards |
| `SETTLEMENT_ROLE` (AccountManager) | `ConversionEngine` | Settle before Genesis burn |
| `EXECUTOR_ROLE` (RewardStrategyManager) | `FeeEngine`, operator | Execute strategies |
| `CALLER_ROLE` (TraitGenerator) | `ConversionEngine` | Generate/release traits |

Chinese version: [modules.zh.md](./modules.zh.md).
