English | [中文](./CHANGELOG.zh.md)

# Changelog

All notable changes to Flux Core are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-21

Initial release of Flux Core: a fixed-supply, dual-form NFT/FT asset protocol.

### Added

- Core asset state machine: `AssetRegistry`, `ConversionEngine` and `CreditManager`, with lazy
  state derivation and guarded transitions.
- `FluxToken` (ERC-20 + Permit, capped supply) and `DynamicNFT` (ERC-721 with asset id, Genesis flag
  and frozen trait seed).
- Fully on-chain trait generation and SVG rendering through `TraitStorage`, `TraitGenerator`,
  `TraitRenderer` and the body/face/head renderers.
- ERC-6551-style account layer: `ERC6551Registry`, `FluxAccount` and `AccountManager` with
  deterministic accounts and atomic settlement before Genesis burn.
- Genesis launch: `GenesisAuction` continuous uniform-price CCA, `CCAAllocator` clearing/allocation
  library, batched credit claims, refunds and LP bootstrap.
- Reward stack: `RewardAssetRegistry`, `RewardVault`, `GenesisVault` and
  `RewardStrategyManager` with pro-rata accounting and pluggable `HoldETHStrategy`.
- Fee stack: `FeeEngine`, `BalanceEngine`, `FeeCurve` and the liquidity/balance/protocol vaults.
- Flux AMM (`FluxAMMFactory`, `FluxNativePair`, `FluxSwapRouter`) plus Uniswap V2/V4 and VRF
  adapters for testnet and production wiring.
- Foundry deployment and interaction scripts for the full stack, auction lifecycle, protocol
  actions and AMM swaps.
- Bilingual documentation (English + `*.zh.md`) covering architecture, modules, flows, deployment,
  security, static analysis and FAQ.
- MIT license, contributing guide, security policy, code of conduct, maintainers file and GitHub
  issue/PR templates.
- CI for build, tests, coverage, Slither and documentation language checks, plus the
  `scripts/check-coverage.sh` 98% line-coverage gate.
- 85 Foundry tests: unit, integration, fuzz round-trip and invariant suites.

### Security

- Strict checks-effects-interactions ordering in auction claims and Genesis removal.
- `SafeERC20` for token transfers and approvals; explicit success checks on native ETH sends.
- Overflow-safe AMM output math with the fee factor kept in the numerator.
- Validation of NFT burn return data and zero-address checks on critical configuration paths.
- Slither analysis with no High or Medium findings under the documented exclusions.
- No third-party audit. See [SECURITY.md](./SECURITY.md) and [docs/security.md](./docs/security.md).

Chinese version: [CHANGELOG.zh.md](./CHANGELOG.zh.md).
