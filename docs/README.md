English | [中文](./README.zh.md)

# Flux Core Documentation

This documentation covers the contracts in `src/` and the scripts in `script/`. Dependency code under
`lib/` is out of scope.

Suggested reading order:

1. [architecture.md](./architecture.md) — the system in one page: layers, state model, invariants
2. [modules.md](./modules.md) — what each contract does, who may call it, what it depends on
3. [flows.md](./flows.md) — auction, conversion, fee, reward, burn and AMM call paths
4. [deployment.md](./deployment.md) — deploy, verify and hand over admin rights
5. [security.md](./security.md) — trust model, external assumptions and known limitations
6. [static-analysis.md](./static-analysis.md) — Slither results, fixes and exclusions
7. [faq.md](./faq.md) — common questions and edge cases
8. [../CHANGELOG.md](../CHANGELOG.md) — release history

## 30-second pitch

Flux turns 10,000 fixed-supply Asset Units into a two-sided market:

- Each Unit is one NFT **or** 10,000 FLUX, never both.
- Genesis sells 5,000 Credits through a continuous uniform-price auction and seeds FLUX/ETH
  liquidity with the proceeds and the remaining 5,000 Units.
- Credit holders choose a Genesis NFT (permanent reward share + ERC-6551 account) or an
  immediately liquid FT position.
- NFT and FT are convertible in both directions; the protocol charges a dynamic fee/reward based on
  the FT share and routes fees through a four-way split.

In one line: **a fixed-supply asset with an NFT/FT conversion engine, a CCA launch and on-chain
rewards.**

## Source map

```text
src/
├── core/          # AssetRegistry, ConversionEngine, CreditManager
├── token/         # FluxToken, DynamicNFT
├── account/       # ERC-6551 registry, FluxAccount, AccountManager
├── genesis/       # GenesisAuction, CCAAllocator
├── trait/         # trait storage/generation and on-chain SVG renderers
├── economic/      # fees, balance curve, reward registry/vault/strategy
├── vault/         # liquidity, balance and protocol vaults
├── strategy/      # reward strategy adapters
├── integration/   # VRF, Uniswap adapters, Flux AMM
└── interfaces/    # shared interfaces
```

## Core concepts

| Topic | Summary |
|---|---|
| Asset Unit | The unit of account. 10,000 exist; each is an NFT or 10,000 FLUX. |
| Credit | A claim on one Asset Unit sold in the Genesis auction. |
| Genesis NFT | A Credit materialized as an NFT with a permanent reward share and an ERC-6551 account. |
| FT | 10,000 FLUX backed by one Asset Unit. Fungible and transferable. |
| Lazy state | Untouched Asset ids are derived from the initial Credit/FT split; only transitions write storage. |
| Dynamic fee | `BalanceEngine` raises the fee when converting in the direction that moves the FT share away from 30–40%. |
| Reward budget | `BalanceVault` releases a bounded fraction of its balance per day for conversion rewards. |

Chinese version: [README.zh.md](./README.zh.md).
