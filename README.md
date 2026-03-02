# opencode-copilot-meter

English | [中文](README.zh-CN.md)

Copilot billing can be hard to track in [OpenCode](https://opencode.ai). `opencode-copilot-meter` is a plugin that makes usage visible with premium-call alerts, end-of-turn summaries (calls, token I/O, optional quota), and Copilot OAuth token show/set scripts. Supports macOS, Linux, and Windows.
For a quick overview of request charging, jump to [How Copilot billing works](#how-copilot-billing-works).

## Features

- **Premium request alert** — Instant toast notification whenever a premium (billing) API call fires, showing provider, model, and caller identity — so you know the moment it costs you
- **Turn summary** — Automatic end-of-turn summary: total calls, input/output token usage, and optional remaining quota percentage (requires quota endpoint configuration) — a clear snapshot of what each conversation turn actually cost
- **Copilot OAuth token management** — View and set the Copilot OAuth token via slash commands or terminal scripts without leaving your workflow

## Installation

**Quick install (no clone/build):**

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/install.sh | bash
# Windows (PowerShell)
irm https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/install.ps1 | iex
```

**Uninstall:**

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/uninstall.sh | bash
# Windows (PowerShell)
irm https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/uninstall.ps1 | iex
```

**From source:**

```bash
git clone https://github.com/niubtree/opencode-copilot-meter.git
cd opencode-copilot-meter
# macOS/Linux
bash local-install.sh
# Windows (PowerShell)
pwsh local-install.ps1
```

This installs the committed `dist/` artifacts (no build required). Restart OpenCode to activate. You can review every file before running with no extra network requests.

## Usage

In normal cases, the plugin works immediately after installation with zero configuration.

- No setup is required for basic premium-call and token-usage tracking.
- If Copilot auth is not configured and you want to use Copilot, set your Copilot OAuth token first with `copilot-set-token`.
- Remaining quota sync requires a quota endpoint. Because this is not a public Copilot API, this repo does not publish a default endpoint. You can search for one yourself or host your own endpoint.

### Toast notifications

| Toast | When | Example |
|-------|------|---------|
| Premium call | Each premium API call | `💰 [premium] github-copilot/claude-sonnet-4-20250514 (coder)` |
| Summary | Turn ends | `github-copilot/claude-sonnet-4-20250514 \| 3 calls \| 45.2k->8.1k \| quota: 180/300 (60.0%)` |

### Terminal scripts (recommended)

After installation, scripts are available at `~/.config/opencode/scripts/copilot-meter/`.
Use terminal scripts for token/quota endpoint operations. They run locally and do not require LLM interaction.

```bash
# macOS/Linux
~/.config/opencode/scripts/copilot-meter/copilot-show-token.sh
~/.config/opencode/scripts/copilot-meter/copilot-set-token.sh gho_...
~/.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.sh <quota-endpoint>
~/.config/opencode/scripts/copilot-meter/copilot-show-quota.sh

# Windows PowerShell (same directory, .ps1 extension)
~/.config/opencode/scripts/copilot-meter/copilot-show-token.ps1
~/.config/opencode/scripts/copilot-meter/copilot-set-token.ps1 gho_...
~/.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.ps1 <quota-endpoint>
~/.config/opencode/scripts/copilot-meter/copilot-show-quota.ps1
```

### Slash commands (optional)

You can also run commands inside OpenCode, for example:
`/copilot-help`, `/copilot-show-token`, `/copilot-set-token`, `/copilot-show-quota`, `/copilot-set-quota-endpoint`.

> **Security warning:** In OpenCode, slash commands are prompt templates and may involve LLM interaction. This creates avoidable exposure risk for sensitive values like Copilot OAuth tokens.
> **Strong recommendation:** For token/endpoint management, use terminal scripts only. Slash commands are not necessary for these operations.

## Development

For local development:

```bash
bun install
```

After changing `src/`, rebuild and deploy to your OpenCode config:

```bash
bun run install:plugin
```

`install:plugin` already runs build and installs plugin/scripts/commands to `~/.config/opencode/`.
Use `bun run build` only when you want to refresh `dist/` without installing.

Restart OpenCode to pick up changes.

## Security & Disclaimer

- This is a community plugin and is not officially affiliated with GitHub.
- You are responsible for storing and using your Copilot OAuth token securely.
- Do not commit tokens, paste them into AI chat content, or expose them in logs.
- If token leakage causes quota loss, account risk, or other damage, rotate credentials immediately; the project maintainers are not liable for losses caused by credential exposure or misuse.

## License

[MIT](LICENSE)

## How Copilot billing works

GitHub Copilot bills by **premium requests**. The Pro plan includes 300 per month, and each model has a different multiplier — Claude Opus costs 3× per request, while lighter models like Grok fast cost as little as 0.25×.

**Important note:** Billing is completely unrelated to token usage (input, output, reasoning, or cache tokens) — only the number of premium requests counts toward your quota.

### What counts as one request?

Only the moment you press Enter to send a message. That's it.

Everything the agent does after that is free: spawning sub-agents, calling tools, reading files, running commands, MCP interactions, multi-step reasoning — none of it counts toward your quota, regardless of how many internal API calls are made.

### Making your quota count

This billing model rewards **detailed, complex tasks** over frequent back-and-forth.

❌ **Chat-style** — each message is a separate premium request:

<img src="assets/use-as-chat.jpg" alt="Chat-style: person chatting back and forth with a robot while quota drains fast" width="480">

```text
You: check what's wrong with the auth module       # 1 request (3× for Opus)
You: refactor it to use JWT                        # 1 request
You: add unit tests                                # 1 request
You: update the error messages too                 # 1 request
                                           Total: 4 requests (12× for Opus)
```

✅ **Spec-style** — one prompt, one request:

<img src="assets/use-as-spec.jpg" alt="Spec-style: person hands spec to robot then relaxes with coffee" width="480">

```text
You: Refactor the auth module from session cookies
     to JWT. Add unit tests for all new functions.
     Update error messages to include error codes.
                                           Total: 1 request (3× for Opus)
```

The agent handles complexity on its own — spawning sub-agents, calling tools, iterating as needed — all within that single request. Whether your prompt runs for 30 seconds or 30 minutes, it's still one request.

> **Note:** Certain edge cases (context window overflow, timeouts, unexpected errors) can interrupt a turn and require a follow-up message. These are uncommon and not covered here.
