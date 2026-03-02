import type { Plugin } from "@opencode-ai/plugin"
import { appendFileSync, chmodSync, readFileSync, renameSync, writeFileSync } from "fs"
import { tmpdir, homedir } from "os"
import { join } from "path"

// --- Logging system ---
const LOG_FILE = join(tmpdir(), "copilot-meter.log")
const LOG_FILE_OLD = join(tmpdir(), "copilot-meter.log.old")

function rotateLog() {
  try { renameSync(LOG_FILE, LOG_FILE_OLD) } catch {}
  try { writeFileSync(LOG_FILE, "", { mode: 0o600 }) } catch { writeFileSync(LOG_FILE, "") }
  try { chmodSync(LOG_FILE, 0o600) } catch {}
}

function log(tag: string, data: Record<string, unknown> = {}) {
  const ts = new Date().toISOString()
  const payload = Object.keys(data).length > 0
    ? " " + Object.entries(data).map(([k, v]) => `${k}=${typeof v === "string" ? v : JSON.stringify(v)}`).join(" ")
    : ""
  appendFileSync(LOG_FILE, `${ts} [${tag}]${payload}\n`)
}

function logToast(tag: string, toast: { title: string; message: string; variant: string; duration: number }) {
  log(tag, { toast_message: toast.message, toast_variant: toast.variant, toast_duration: toast.duration })
}

// Config file: ~/.config/opencode/copilot-meter.json  (XDG_CONFIG_HOME fallback)
function getConfigPath(): string {
  const base = process.env.XDG_CONFIG_HOME
    || join(homedir(), ".config")
  return join(base, "opencode", "copilot-meter.json")
}

function readConfig(): Record<string, any> {
  try {
    return JSON.parse(readFileSync(getConfigPath(), "utf8"))
  } catch {
    return {}
  }
}

// Auth file: ~/.local/share/opencode/auth.json  (XDG_DATA_HOME fallback)
function getCopilotToken(): string {
  try {
    const base = process.env.XDG_DATA_HOME
      || join(homedir(), ".local", "share")
    const raw = readFileSync(join(base, "opencode", "auth.json"), "utf8")
    const data = JSON.parse(raw)
    const entry = data["github-copilot-enterprise"] || data["github-copilot"]
    return entry?.refresh ?? ""
  } catch {
    return ""
  }
}

async function fetchQuotaRemaining(): Promise<string | null> {
  const config = readConfig()
  const endpoint: string = config.quota_endpoint || ""
  if (!endpoint) {
    log("quota", { status: "skipped", reason: "no endpoint configured" })
    return null
  }

  const token = getCopilotToken()
  if (!token) {
    log("quota", { status: "skipped", reason: "no copilot token found" })
    return null
  }

  try {
    const res = await fetch(endpoint, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    })
    if (!res.ok) {
      log("quota", { status: "error", httpStatus: res.status })
      return null
    }
    const data: any = await res.json()
    const snap = data?.quota_snapshots?.premium_interactions
    if (!snap) {
      log("quota", { status: "error", reason: "no premium_interactions in response" })
      return null
    }
    const remaining: number = snap.quota_remaining ?? snap.remaining
    const entitlement: number = snap.entitlement
    const pct: number = snap.percent_remaining
    const remainStr = Number.isInteger(remaining) ? String(remaining) : remaining.toFixed(1)
    const result = `quota: ${remainStr}/${entitlement} (${pct?.toFixed(1)}%)`
    log("quota", { status: "ok", remaining, entitlement, pct })
    return result
  } catch (e) {
    log("quota", { status: "error", error: String(e) })
    return null
  }
}

interface Tokens {
  input: number
  output: number
  reasoning: number
  cacheRead: number
  cacheWrite: number
}

function emptyTokens(): Tokens {
  return { input: 0, output: 0, reasoning: 0, cacheRead: 0, cacheWrite: 0 }
}

function fmt(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M"
  if (n >= 1_000) return (n / 1_000).toFixed(1) + "k"
  return String(n)
}

// Root session ID — set on first chat.message of each turn, used to filter
// session.idle events. Only the first chat.message sets this (root session);
// subsequent chat.message events during the same turn are from sub-agents
// and are ignored. Reset after summary fires so the next turn starts fresh.
let currentSessionID = ""

export const CopilotMeterPlugin: Plugin = async (ctx) => {
  const client = ctx.client

  // Rotate log file if it exceeds size limit (keeps current + one .old backup)
  rotateLog()
  log("plugin.loaded")

  // Per-turn accumulators — reset on each user message
  let turn = {
    calls: 0,
    steps: 0,
    reasons: {} as Record<string, number>,
    tokens: emptyTokens(),
    tools: [] as string[],
    model: "",
  }

  function resetTurn() {
    turn = { calls: 0, steps: 0, reasons: {}, tokens: emptyTokens(), tools: [], model: "" }
  }

  function showToast(tag: string, toast: { title: string; message: string; variant: "info" | "warning" | "error" | "success"; duration: number }) {
    logToast(tag, toast)
    client.tui.showToast({ body: toast }).catch(() => {})
  }

  async function printTurnSummary() {
    const t = turn.tokens
    const totalTokens = t.input + t.output + t.reasoning + t.cacheRead
    if (totalTokens === 0) {
      log("summary.skip", { reason: "zero tokens" })
      return
    }

    // Log full turn state for debugging
    log("summary.turn_state", {
      calls: turn.calls,
      steps: turn.steps,
      reasons: turn.reasons,
      tokens: turn.tokens,
      tools: turn.tools,
      model: turn.model,
    })

    const parts: string[] = []

    if (turn.model) parts.push(turn.model)
    parts.push(`${turn.calls} call${turn.calls !== 1 ? "s" : ""}`)
    parts.push(`${fmt(t.input)}→${fmt(t.output)}`)

    // Fetch quota remaining if endpoint is configured
    const quota = await fetchQuotaRemaining()
    if (quota) parts.push(quota)

    const message = parts.join(" | ")
    showToast("toast.summary", {
      title: "copilot-meter",
      message,
      variant: "info",
      duration: 30000,
    })
  }

  // Debounce summary: wait briefly after session.idle to confirm the turn is truly over.
  // If session.status(busy) fires during the wait, the turn is still running — cancel.
  // This handles: (1) processor.ts error → idle → loop exit → idle (double-fire),
  //               (2) any future OpenCode changes that might introduce brief idle gaps.
  let summaryTimer: ReturnType<typeof setTimeout> | null = null
  const SUMMARY_DEBOUNCE_MS = 300

  function scheduleSummary() {
    cancelSummary()
    summaryTimer = setTimeout(async () => {
      summaryTimer = null
      log("summary.debounce_fired")
      await printTurnSummary()
      // Reset root session ID so the next user turn starts fresh.
      // Without this, the next chat.message would be seen as "same root session"
      // and wouldn't reset turn accumulators.
      currentSessionID = ""
    }, SUMMARY_DEBOUNCE_MS)
  }

  function cancelSummary() {
    if (summaryTimer) {
      clearTimeout(summaryTimer)
      summaryTimer = null
    }
  }

  return {
    "chat.message": async (input) => {
      const sessionID = (input as any).sessionID ?? ""
      if (currentSessionID && sessionID !== currentSessionID) {
        // Sub-agent chat.message — ignore. Don't overwrite root session ID
        // and don't reset turn accumulators (sub-agent tokens should accumulate).
        log("hook.chat.message", { action: "skip", reason: "sub-agent session", sessionID, currentSessionID })
        return
      }
      // First chat.message of a new turn (root session), or same root session re-entry
      currentSessionID = sessionID
      log("hook.chat.message", { sessionID: currentSessionID })
      cancelSummary()
      resetTurn()
    },

    "chat.headers": async (input, output) => {
      // Skip hidden agents (title/summarizer) — they don't increment turn.calls
      const agent = (input as any).agent
      const hidden = agent?.hidden === true
      const agentName = typeof agent === "string" ? agent : agent?.name ?? ""

      if (hidden) {
        log("hook.chat.headers", { action: "skip", reason: "hidden agent", agent: agentName })
        return
      }

      const provider = (input.provider as any)?.info?.id || (input.model as any)?.providerID || ""
      const model = input.model?.id ?? "unknown"
      const label = provider ? `${provider}/${model}` : model
      const isCopilot = provider.includes("github-copilot")

      // x-initiator override: only present for sub-agent sessions (forced to "agent" by copilot plugin)
      const initiatorOverride = output.headers["x-initiator"] || undefined
      // turn.calls already incremented by chat.params (which fires before chat.headers)
      // First non-hidden call = user-initiated (premium), rest = agent continuation
      const initiator = initiatorOverride
        ?? (isCopilot ? (turn.calls === 1 ? "user" : "agent") : undefined)

      log("hook.chat.headers", {
        provider, model, label, isCopilot,
        calls: turn.calls, initiatorOverride: initiatorOverride ?? "none", initiator: initiator ?? "n/a",
        agent: agentName,
      })

      const isPremium = isCopilot && initiator === "user"

      // Check config: suppress non-premium call toasts unless noise_mode is true
      if (!isPremium) {
        const config = readConfig()
        const noiseMode = config.noise_mode === true
        if (!noiseMode) {
          log("hook.chat.headers", { action: "suppress_toast", reason: "non-premium, noise_mode=false" })
          return
        }
      }

      const parts: string[] = []
      if (isCopilot) {
        parts.push(initiator === "user" ? "💰 [premium]" : "[agent]")
      }
      parts.push(label)
      if (agentName) parts.push(`(${agentName})`)

      showToast("toast.call", {
        title: "copilot-meter",
        message: parts.join(" "),
        variant: isPremium ? "warning" : "info",
        duration: 5000,
      })
    },

    "chat.params": async (input) => {
      const agent = input.agent as any
      const agentName = agent?.name ?? "unknown"
      const hidden = agent?.hidden === true

      if (hidden) {
        log("hook.chat.params", { action: "skip", reason: "hidden agent", agent: agentName, model: input.model?.id })
        return
      }

      turn.calls++
      if (input.provider?.info?.id) {
        turn.model = `${input.provider.info.id}/${input.model.id}`
      } else if (input.model?.id) {
        turn.model = input.model.id
      }

      log("hook.chat.params", {
        agent: agentName, model: input.model?.id,
        "turn.calls": turn.calls, "turn.model": turn.model,
      })
    },

    "tool.execute.after": async (input) => {
      turn.tools.push(input.tool)
      log("hook.tool.execute.after", { tool: input.tool, "turn.tools_count": turn.tools.length })
    },

    event: async ({ event }) => {
      if (event.type === "message.part.updated") {
        const part = (event as any).properties?.part
        if (part?.type === "step-finish") {
          turn.steps++
          const reason = part.reason ?? "unknown"
          turn.reasons[reason] = (turn.reasons[reason] ?? 0) + 1
          const tokens = part.tokens as { total: number; input: number; output: number; reasoning: number; cache?: { read: number; write: number } }
          turn.tokens.input += tokens.input ?? 0
          turn.tokens.output += tokens.output ?? 0
          turn.tokens.reasoning += tokens.reasoning ?? 0
          turn.tokens.cacheRead += tokens.cache?.read ?? 0
          turn.tokens.cacheWrite += tokens.cache?.write ?? 0

          log("event.step-finish", {
            step: turn.steps, reason,
            input: tokens.input, output: tokens.output,
            reasoning: tokens.reasoning ?? 0,
            cacheRead: tokens.cache?.read ?? 0, cacheWrite: tokens.cache?.write ?? 0,
            "turn.tokens.input": turn.tokens.input, "turn.tokens.output": turn.tokens.output,
          })
        }
      }

      if (event.type === "session.idle") {
        const idleSessionID = (event as any).properties?.sessionID
        if (!idleSessionID || idleSessionID !== currentSessionID) {
          log("event.session.idle", {
            action: "skip", reason: idleSessionID ? "non-root session" : "no sessionID",
            idleSessionID: idleSessionID ?? "none", currentSessionID,
          })
          return
        }
        log("event.session.idle", { action: "schedule_summary", sessionID: idleSessionID })
        scheduleSummary()
      }

      // Cancel pending summary if session becomes busy again (turn not over)
      if (event.type === "session.status") {
        const props = (event as any).properties
        if (props?.status?.type === "busy" && props?.sessionID === currentSessionID) {
          if (summaryTimer) {
            log("event.session.status", { action: "cancel_summary", reason: "session busy again" })
            cancelSummary()
          }
        }
      }
    },
  }
}
