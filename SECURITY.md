English | [中文](./SECURITY.zh.md)

# Security Policy

## Supported versions

Only the latest commit on `main` is supported. There are no maintained release branches yet.

## Reporting a vulnerability

**Do not open a public issue, pull request or discussion for a vulnerability.**

Report privately through one of:

1. GitHub Security Advisories: <https://github.com/lukema95/flux-core/security/advisories/new>
2. Email the maintainers listed in [MAINTAINERS.md](./MAINTAINERS.md) with `[SECURITY]` in the
   subject.

Include:

- affected commit/tag and contract
- a description of the issue and its impact
- a minimal reproduction (a Foundry test is ideal)
- any suggested fix or mitigation
- whether the issue is already public

We aim to acknowledge reports within 72 hours and to provide a remediation plan within 14 days.
Please allow time for a fix and coordinated disclosure before publishing details.

## Scope

In scope:

- contracts under `src/`
- deployment and interaction scripts under `script/`
- access-control, accounting and fund-flow logic

Out of scope:

- test-only mocks (`test/`, `MockLiquidityAdapter`, `MockUniswapV4Migrator`,
  `MockUniswapV2Migrator`, `MockRandomProvider`, `SyncVRFRandomProvider`)
- dependency code under `lib/`
- front-end or subgraph code in consuming applications
- gas optimisations without a security impact
- issues that require a compromised admin key or a malicious external integration configured by the
  admin

## Safe harbour

We will not pursue legal action for good-faith research that follows this policy, avoids privacy
violations, avoids data destruction and does not exploit the issue beyond a minimal proof of concept.
Do not test against mainnet deployments without written permission.

## Bug bounty

No bug bounty is currently offered. We credit reporters in the release notes unless they prefer to
remain anonymous.

## Related documents

- [Security model](./docs/security.md)
- [Static analysis](./docs/static-analysis.md)
- [Contributing](./CONTRIBUTING.md)

Chinese version: [SECURITY.zh.md](./SECURITY.zh.md).
