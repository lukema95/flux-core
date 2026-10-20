[English](./SECURITY.md) | 中文

# 安全策略

## 支持的版本

仅支持 `main` 上的最新提交。目前尚无维护中的发布分支。

## 报告漏洞

**切勿为漏洞创建公开 issue、拉取请求或讨论。**

请通过以下任一方式私下报告：

1. GitHub Security Advisories：<https://github.com/lukema95/flux-core/security/advisories/new>
2. 发送邮件给 [MAINTAINERS.zh.md](./MAINTAINERS.zh.md) 中列出的维护者，并在主题中注明
   `[SECURITY]`。

请包含：

- 受影响的提交/标签与合约
- 问题描述及其影响
- 最小复现（Foundry 测试最佳）
- 任何建议的修复或缓解措施
- 该问题是否已经公开

我们力求在 72 小时内确认报告，并在 14 天内提供修复计划。在公布细节之前，请留出修复与
协调披露的时间。

## 范围

范围内：

- `src/` 下的合约
- `script/` 下的部署与交互脚本
- 访问控制、记账与资金流逻辑

范围外：

- 仅用于测试的 mock（`test/`、`MockLiquidityAdapter`、`MockUniswapV4Migrator`、
  `MockUniswapV2Migrator`、`MockRandomProvider`、`SyncVRFRandomProvider`）
- `lib/` 下的依赖代码
- 使用方应用中的前端或子图代码
- 无安全影响的 gas 优化
- 需要管理员密钥被攻陷，或需要管理员配置恶意外部集成才能触发的问题

## 安全港

对于遵循本策略、避免侵犯隐私、避免破坏数据，且不将问题利用超出最小概念验证范围的善意研究，
我们不会采取法律行动。未经书面许可，请勿针对主网部署进行测试。

## 漏洞赏金

目前不提供漏洞赏金。除非报告者希望保持匿名，否则我们会在发布说明中致谢。

## 相关文档

- [安全模型](./docs/security.zh.md)
- [静态分析](./docs/static-analysis.zh.md)
- [贡献指南](./CONTRIBUTING.zh.md)

英文版本：[SECURITY.md](./SECURITY.md)。
