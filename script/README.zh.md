[English](./README.md) | 中文

# 脚本

用于部署与交互的 Foundry 脚本。所有脚本都从环境变量读取配置；运行前请将
[`.env.example`](../.env.example) 复制为 `.env`，填写完整并执行 `source .env`。

## 封装脚本

`flux-forge.sh` 会加载 `.env`，将 `--network` 映射到 `[rpc_endpoints]` 别名，并把其余参数
转发给 `forge`：

```bash
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
./script/flux-forge.sh script script/AuctionActions.s.sol:BidAuction --network bsc --broadcast
./script/flux-forge.sh cast balance 0x... --network local
```

支持的网络：`local`、`monad`、`bsc`、`hyperliquid`，以及 `*_testnet` 别名。

## 部署

```bash
./script/flux-forge.sh script script/Deploy.s.sol:Deploy --network monad --broadcast
```

部署完整协议栈、配置角色，可选地将管理员权限移交给 `PROTOCOL_ADMIN`，并写入
`deployments/<chainId>.json`（或 `DEPLOYMENTS_DIR`）。

## 拍卖生命周期

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

## 协议操作

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

## Flux AMM 兑换

```bash
FLUX_SWAP_ROUTER=0x... FluxToken=0x... SWAP_ETH_IN=0.01ether MIN_TOKEN_OUT=0 \
  ./script/flux-forge.sh script script/SwapActions.s.sol:SwapETHForFlux --network monad --broadcast

FLUX_SWAP_ROUTER=0x... FluxToken=0x... SWAP_TOKEN_IN=1000000000000000000 MIN_ETH_OUT=0 \
  ./script/flux-forge.sh script script/SwapActions.s.sol:SwapFluxForETH --network monad --broadcast
```

## 环境变量参考

完整列表见 [docs/deployment.zh.md](../docs/deployment.zh.md#4-环境变量)。每次写操作
都需要：`PRIVATE_KEY` 以及所选网络的 RPC。

英文版本：[README.md](./README.md)。
