English | [中文](./CONTRIBUTING.zh.md)

# Contributing

Thanks for improving Flux Core. This repository contains the contracts layer.

## Setup

```bash
git clone git@github.com:lukema95/flux-core.git
cd flux-core
git submodule update --init lib/forge-std lib/openzeppelin-contracts

forge build
forge test
```

Foundry **v1.8.5** is the version used by CI. Solc is pinned to `0.8.26` in `foundry.toml`.

## Local checks

Run these before opening a pull request:

```bash
forge fmt --check
forge build
forge test -vv
bash scripts/check-coverage.sh     # >= 98% line coverage of src/
bash scripts/check-docs.sh         # every doc has a .zh.md counterpart
SLITHER_BIN=.venv/bin/slither bash scripts/run-slither.sh
```

Coverage uses `--ir-minimum`; the threshold is `COVERAGE_THRESHOLD` (default `98`).

## Change guidelines

- Keep the public ABI and storage layout stable unless the change is explicitly breaking.
- Add a regression test for every bug fix.
- Prefer checks-effects-interactions and `nonReentrant` on new external-call paths.
- Use `SafeERC20` for token transfers and verify call success.
- Do not add new admin roles without documenting them in [docs/modules.md](./docs/modules.md) and
  [docs/security.md](./docs/security.md).
- Contracts are MIT-licensed; every new Solidity file needs
  `// SPDX-License-Identifier: MIT`.

## Commit style

Use short imperative subjects, optionally with a conventional prefix:

```text
fix: order auction refund state before external calls
feat: add v4 migrator integration tests
docs: document the role handoff in deployment.zh.md
test: cover protocol vault zero-recipient validation
```

Reference the affected module in the body when the change is non-trivial.

## Pull requests

A pull request should include:

- what changed and why
- the risk/behaviour change
- the commands used to verify it
- updated English and Chinese documentation when user-facing behaviour changes
- no secrets, `.env` files, private keys or RPC credentials

The PR template in `.github/PULL_REQUEST_TEMPLATE.md` mirrors this checklist.

## Documentation

All documents are bilingual. English files use `.md`; Chinese files use `.zh.md`. When you add or
rename a document, add both versions. `bash scripts/check-docs.sh` enforces the pairs.

## Security

Never open a public issue for a vulnerability. Follow [SECURITY.md](./SECURITY.md).

## License

By contributing you agree that your contribution is licensed under the [MIT License](./LICENSE) and
that you have the right to submit it.

Chinese version: [CONTRIBUTING.zh.md](./CONTRIBUTING.zh.md).
