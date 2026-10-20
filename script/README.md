English | [中文](./README.zh.md)

# Scripts

Foundry scripts for deployment and interaction. All scripts read configuration from environment
variables; copy [`.env.example`](../.env.example) to `.env`, fill it in and `source .env` before
running them.

## Wrapper

`flux-forge.sh` loads `.env`, maps `--network` to a `[rpc_endpoints]` alias and forwards the rest of
the arguments to `forge`:

```bash
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
./script/flux-forge.sh script script/AuctionActions.s.sol:BidAuction --network bsc --broadcast
./script/flux-forge.sh cast balance 0x... --network local
```

Supported networks: `local`, `monad`, `bsc`, `hyperliquid`, plus the `*_testnet` aliases.

## Deploy

```bash
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
```

Deploys the full stack, wires roles, optionally hands admin to `PROTOCOL_ADMIN` and writes
`deployments/<chainId>.json` (or `DEPLOYMENTS_DIR`).

## Auction lifecycle

```bash
# schedule
GENESIS_AUCTION=0x... AUCTION_START=<unix> AUCTION_END=<unix> \
  ./script/flux-forge.sh script script/StartAuction.s.sol:StartAuction --network monad --broadcast

# bid
GENESIS_AUCTION=0x... MAX_PRICE=2000000000000000000 BID_BUDGET=10000000000000000000 \
  ./script/flux-forge.sh script script/AuctionActions.s.sol:BidAuction --network monad --broadcast

# finalize
GENESIS_AUCTION=0x... \
  ./script/flux-forge.sh script script/AuctionActions.s.sol:FinalizeAuction --network monad --broadcast

# claim credits / refund
GENESIS_AUCTION=0x... \
  ./script/flux-forge.sh script script/AuctionActions.s.sol:ClaimAuctionCredit --network monad --broadcast
GENESIS_AUCTION=0x... CLAIM_BATCH_SIZE=200 \
  ./script/flux-forge.sh script script/AuctionActions.s.sol:ClaimAuctionCreditBatch --network monad --broadcast
GENESIS_AUCTION=0x... \
  ./script/flux-forge.sh script script/AuctionActions.s.sol:ClaimAuctionCreditAll --network monad --broadcast
```

## Protocol actions

```bash
# Credit → Genesis NFT
CONVERSION_ENGINE=0x... ASSET_ID=1 TRAIT_SEED=123 \
  ./script/flux-forge.sh script script/ProtocolActions.s.sol:MaterializeGenesisNFT --network monad --broadcast

# Credit → FT
CONVERSION_ENGINE=0x... ASSET_ID=1 \
  ./script/flux-forge.sh script script/ProtocolActions.s.sol:MaterializeFT --network monad --broadcast

# NFT → FT (fee is quoted automatically)
CONVERSION_ENGINE=0x... TOKEN_ID=1 \
  ./script/flux-forge.sh script script/ProtocolActions.s.sol:ConvertNFTToFT --network monad --broadcast

# FT → NFT
CONVERSION_ENGINE=0x... TRAIT_SEED=456 \
  ./script/flux-forge.sh script script/ProtocolActions.s.sol:ConvertFTToNFT --network monad --broadcast

# claim Genesis rewards / distribute fees
GENESIS_VAULT=0x... TOKEN_ID=1 \
  ./script/flux-forge.sh script script/ProtocolActions.s.sol:ClaimGenesisRewards --network monad --broadcast
FEE_ENGINE=0x... \
  ./script/flux-forge.sh script script/ProtocolActions.s.sol:DistributeFees --network monad --broadcast
```

## Flux AMM swaps

```bash
FLUX_SWAP_ROUTER=0x... FluxToken=0x... SWAP_ETH_IN=0.01ether MIN_TOKEN_OUT=0 \
  ./script/flux-forge.sh script script/SwapActions.s.sol:SwapETHForFlux --network monad --broadcast

FLUX_SWAP_ROUTER=0x... FluxToken=0x... SWAP_TOKEN_IN=1000000000000000000 MIN_ETH_OUT=0 \
  ./script/flux-forge.sh script script/SwapActions.s.sol:SwapFluxForETH --network monad --broadcast
```

## Environment reference

See [docs/deployment.md](../docs/deployment.md#4-environment-variables) for the full list. Required
variables for every write: `PRIVATE_KEY` and the RPC for the selected network.

Chinese version: [README.zh.md](./README.zh.md).
