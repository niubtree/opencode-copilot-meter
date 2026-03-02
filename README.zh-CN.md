# opencode-copilot-meter

[English](README.md) | 中文

在 [OpenCode](https://opencode.ai) 里，Copilot 的计费和 token 消耗不容易直观看到。`opencode-copilot-meter` 通过 premium 调用提醒、回合汇总（调用次数、输入/输出 token、可选配额）以及 token 查看/设置脚本，把使用成本直接展示出来。支持 macOS、Linux 和 Windows。
想快速了解请求如何计费，可直接跳转到 [Copilot 计费模式](#copilot-计费模式)。

## 功能

- **Premium 请求提醒** — 每次触发 premium（计费）API 调用时即时弹出 toast，显示 provider、model 和调用者身份，让你第一时间知道"这一下花钱了"
- **回合汇总** — 每轮对话结束后自动汇总：本轮总调用次数、输入/输出 token 用量，以及可选的剩余配额百分比（需配置 quota endpoint），一目了然地呈现这轮对话的真实成本
- **Copilot OAuth token 管理** — 通过斜杠命令或终端脚本查看、设置 Copilot OAuth token，无需离开工作流

## 安装

**快速安装（无需 clone/构建）：**

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/install.sh | bash
# Windows (PowerShell)
irm https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/install.ps1 | iex
```

**卸载：**

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/uninstall.sh | bash
# Windows (PowerShell)
irm https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/uninstall.ps1 | iex
```

**从源码安装：**

```bash
git clone https://github.com/niubtree/opencode-copilot-meter.git
cd opencode-copilot-meter
# macOS/Linux
bash local-install.sh
# Windows (PowerShell)
pwsh local-install.ps1
```

该方式直接安装仓库中提交的 `dist/` 构建产物（无需本地构建）。重启 OpenCode 即可生效；运行前可审查全部文件，无额外网络请求。

## 使用

正常情况下，插件安装后即可运行，完全不需要任何配置。

- 基础的 premium 调用和 token 用量追踪开箱即用。
- 如果你还没有配置 Copilot 认证但希望使用 Copilot，请先通过 `copilot-set-token` 设置 Copilot OAuth token。
- 剩余配额同步依赖 quota endpoint。由于这不是 Copilot 公开 API，本仓库不提供默认 endpoint；你可以自行搜索或自建 endpoint。

### Toast 通知

| 通知类型 | 触发时机 | 示例 |
|---------|---------|------|
| Premium 调用 | 每次 premium API 调用 | `💰 [premium] github-copilot/claude-sonnet-4-20250514 (coder)` |
| 汇总 | 回合结束 | `github-copilot/claude-sonnet-4-20250514 \| 3 calls \| 45.2k->8.1k \| quota: 180/300 (60.0%)` |

### 终端脚本（推荐）

安装完成后，脚本位于 `~/.config/opencode/scripts/copilot-meter/`。
涉及 token 和 quota endpoint 的操作，建议只用终端脚本。脚本是本地执行，不需要 LLM 交互。

```bash
# macOS/Linux
~/.config/opencode/scripts/copilot-meter/copilot-show-token.sh
~/.config/opencode/scripts/copilot-meter/copilot-set-token.sh gho_...
~/.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.sh <quota-endpoint>
~/.config/opencode/scripts/copilot-meter/copilot-show-quota.sh

# Windows PowerShell（同目录，扩展名为 .ps1）
~/.config/opencode/scripts/copilot-meter/copilot-show-token.ps1
~/.config/opencode/scripts/copilot-meter/copilot-set-token.ps1 gho_...
~/.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.ps1 <quota-endpoint>
~/.config/opencode/scripts/copilot-meter/copilot-show-quota.ps1
```

### 斜杠命令（可选）

你也可以在 OpenCode 内使用斜杠命令，例如：
`/copilot-help`、`/copilot-show-token`、`/copilot-set-token`、`/copilot-show-quota`、`/copilot-set-quota-endpoint`。

> **安全警告：** OpenCode 内的斜杠命令本质上是提示词模板，可能触发 LLM 交互。对 Copilot OAuth token 这类敏感信息会带来可避免的暴露风险。
> **强烈建议：** token/endpoint 管理只使用终端脚本。对于这类操作，斜杠命令没有必要。

## 开发

本地开发首次准备：

```bash
bun install
```

修改 `src/` 后，重新构建并部署到 OpenCode 配置目录：

```bash
bun run install:plugin
```

`install:plugin` 已包含 build，并会安装 plugin/scripts/commands 到 `~/.config/opencode/`。
如果你只想更新 `dist/` 而不安装，再单独运行 `bun run build`。

重启 OpenCode 以加载更改。

## 安全与免责声明

- 本项目为社区插件，与 GitHub 官方无隶属关系。
- 你需要自行负责 Copilot OAuth token 的保管与使用安全。
- 请勿将 token 提交到仓库、粘贴到 AI 对话内容，或输出到日志中。
- 如因凭据泄漏或误用导致配额损失、账号风险或其他损失，请立即轮换凭据；项目维护者不对由凭据暴露或误用造成的损失承担责任。

## 许可证

[MIT](LICENSE)

## Copilot 计费模式

GitHub Copilot 按 **premium 请求次数**计费。以 Pro 计划为例，每月 300 次，不同模型系数不同——Claude Opus 每次算 3 次，而 Grok fast 等轻量模型只算 0.25 次。

**重要提醒：** 计费与 token 使用量（输入、输出、推理或缓存 token）完全无关——只有 premium 请求的数量才算入你的配额。

### 怎样算"一次"？

你按下 Enter 发送消息的那一刻，算一次。仅此而已。

之后 agent 做的所有事情都不计次：派生 sub-agent、调用 tool、读写文件、执行命令、MCP 交互、多步推理——无论内部触发了多少次 API 调用，都不会消耗你的配额。

### 让每一次都值得

这套计费模式天然奖励**详细的复杂任务**，惩罚频繁的你来我往。

❌ **聊天式** — 每条消息都是一次独立的 premium 请求：

<img src="assets/use-as-chat.jpg" alt="聊天式：人和机器人你一句我一句，额度飞速消耗" width="480">

```text
你: 看看 auth 模块有什么问题                    # 1 次（Opus 算 3 次）
你: 用 JWT 重构一下                            # 1 次
你: 加上单元测试                               # 1 次
你: 错误提示也改一下                            # 1 次
                                    合计: 4 次（Opus 算 12 次）
```

✅ **许愿式 / Spec 式** — 一条 prompt，一次请求：

<img src="assets/use-as-spec.jpg" alt="许愿式：人交代任务后惬意喝咖啡，AI 埋头工作" width="480">

```text
你: 把 auth 模块从 session cookie 重构为 JWT。
    为所有新函数补充单元测试。
    错误提示需要包含错误码。
                                    合计: 1 次（Opus 算 3 次）
```

Agent 会自行处理复杂度——派生子任务、调用工具、反复迭代，全部在这一次请求内完成。不论你的 prompt 执行了 30 秒还是 30 分钟，都只算一次。

> **注意：** 少数情况下（上下文窗口溢出、超时、异常错误）会导致回合中断，需要追加消息。这些属于边界情况，此处不展开。
