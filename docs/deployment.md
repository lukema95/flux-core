English | [中文](./deployment.zh.md)

# Deployment Guide

This guide deploys the complete Flux Core stack to a new EVM chain with Foundry.

## 1. Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) v1.8.5 or newer
- A funded deployer key (`PRIVATE_KEY`)
- An RPC endpoint for the target chain
- `solc 0.8.26` (installed automatically by Foundry)

```bash
cp .env.example .env
# edit PRIVATE_KEY, RPC_URL and the network-specific RPC variable
source .env
```

## 2. What gets deployed

| Order | Contract | Constructor / wiring |
|---|---|---|
| 1 | `AssetRegistry` | `admin`, then `initializeGenesis(5_000)` |
| 2 | `CreditManager`, `FluxToken` | `admin` |
| 3 | `TraitStorage`, `TraitGenerator`, renderers, `TraitRenderer`, `DynamicNFT` | renderer is immutable in the NFT |
| 4 | `RewardAssetRegistry`, `RewardVault`, `GenesisVault` | native ETH registered as a reward asset |
| 5 | `FluxAccount` implementation, `ERC6551Registry`, `AccountManager` | manager is set after construction |
| 6 | `BalanceEngine`, `BalanceVault`, `LiquidityVault`, `ProtocolVault` | `ProtocolVault` receives treasury |
| 7 | Liquidity migrator + adapter | `UNISWAP_V4_MIGRATOR`, `UNISWAP_V2_ROUTER` or mocks |
| 8 | `FluxAMMFactory`, `FluxSwapRouter` | only when the Flux AMM migrator is used |
| 9 | `RewardStrategyManager`, `FeeEngine` | default split 30/25/25/20 |
| 10 | `ConversionEngine` | takes every address above |
| 11 | `GenesisAuction` | credits, FLUX, migrator, liquidity vault |

After deployment the script grants all operational roles and, if `PROTOCOL_ADMIN != deployer`,
transfers every `DEFAULT_ADMIN_ROLE` and the ERC-6551 registry admin to `PROTOCOL_ADMIN` and
renounces the deployer's admin role.

## 3. Deploy

### Local Anvil

```bash
anvil
# in another terminal
source .env
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network local --broadcast
```

### Testnet

```bash
source .env
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network bsc --broadcast
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network hyperliquid --broadcast
```

`flux-forge.sh` loads `.env` and resolves `--network` to the `[rpc_endpoints]` aliases in
`foundry.toml`. Equivalent raw command:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
```

BSC usually requires legacy transactions:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url "$BSC_TESTNET_RPC_URL" --broadcast --legacy
```

### Output

Addresses are written to `deployments/<chainId>.json`. Set `DEPLOYMENTS_DIR` to change the output
directory (the Foundry `fs_permissions` entry must include it).

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

## 4. Environment variables

| Variable | Purpose |
|---|---|
| `PRIVATE_KEY` | Deployer key; never commit it |
| `RPC_URL` | Default/local RPC |
| `MONAD_TESTNET_RPC_URL`, `BSC_TESTNET_RPC_URL`, `HYPERLIQUID_TESTNET_RPC_URL`, `BSC_MAINNET_RPC_URL` | Per-network RPCs used by `[rpc_endpoints]` |
| `PROTOCOL_ADMIN` | Final admin (multisig/timelock); defaults to the deployer |
| `PROTOCOL_TREASURY` | `ProtocolVault` recipient |
| `LP_LOCK` | Uniswap V2 LP lock address |
| `UNISWAP_V2_ROUTER` | Use `UniswapV2LiquidityAdapter`; empty uses the mock adapter |
| `UNISWAP_V4_MIGRATOR` | Use `UniswapV4LiquidityMigrator`; empty uses the Flux AMM/mock path |
| `FLUX_LEGACY_V4_MOCK` | Use `MockUniswapV4Migrator` instead of the Flux AMM |
| `FLUX_SWAP_PROTOCOL_FEE_BPS` | Protocol fee on Flux AMM swaps (default 30 = 0.3%) |
| `VRF_COORDINATOR` | Use `ChainlinkVRFRandomProvider`; empty uses `SyncVRFRandomProvider` |
| `DEPLOYMENTS_DIR` | Output directory (default `deployments`) |
| `ETHERSCAN_API_KEY` | Contract verification |

## 5. Verify contracts

```bash
forge verify-contract \
  --chain bsc_testnet \
  --watch \
  <CONTRACT_ADDRESS> \
  src/genesis/GenesisAuction.sol:GenesisAuction \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" ...)
```

Constructor arguments can be recovered from the deployment transaction or from
`deployments/<chainId>.json`. Verify `GenesisAuction`, `ConversionEngine`, `FluxToken`,
`DynamicNFT` and `GenesisVault` first; they are the public surface users interact with.

## 6. Post-deployment checklist

1. Confirm every role in [modules.md](./modules.md#8-role-matrix) points at the intended contract.
2. Transfer `PROTOCOL_ADMIN` and `PROTOCOL_TREASURY` to a multisig/timelock before mainnet use.
3. Fund `BalanceVault` and `RewardVault` if conversion rewards are expected immediately.
4. Register any non-native reward asset in `RewardAssetRegistry` before depositing it.
5. Schedule the Genesis auction with `StartAuction.s.sol` and verify `startTime`/`endTime`.
6. Copy `deployments/<chainId>.json` into the consuming application's deployment directory.
7. Run a small end-to-end flow on testnet: bid → finalize → claim → materialize → convert.

## 7. Using Flux Core as a submodule

A consuming repository can pin this repository as a Git submodule at `lib/flux-core`:

```bash
git submodule update --init --recursive
forge build
```

It uses the remapping:

```text
flux-core/=lib/flux-core/src/
```

and runs the deployment script from the submodule, writing into the application's own `deployments/`
directory:

```bash
./script/flux-forge.sh script lib/flux-core/script/Deploy.s.sol:Deploy --network bsc --broadcast
```

## 8. Troubleshooting

- **`OutOfFunds`** — the deployer lacks native gas; fund it first.
- **`InvalidSchedule`** — `AUCTION_START` is in the past; choose a future timestamp.
- **`AuctionUndersubscribed`** — total demand did not cover 5,000 Credits; extend the auction or
  accept the refund path.
- **`CoreLiquidityLocked`** — `LiquidityVault.compound` was pointed at the Genesis position, which is
  intentionally locked.
- **Stack too deep during coverage** — use `--ir-minimum` (the coverage script already does).

Chinese version: [deployment.zh.md](./deployment.zh.md).
