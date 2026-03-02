// src/index.ts
import { appendFileSync, chmodSync, readFileSync, renameSync, writeFileSync } from "fs";
import { tmpdir, homedir } from "os";
import { join } from "path";
var LOG_FILE = join(tmpdir(), "copilot-meter.log");
var LOG_FILE_OLD = join(tmpdir(), "copilot-meter.log.old");
function rotateLog() {
  try {
    renameSync(LOG_FILE, LOG_FILE_OLD);
  } catch {}
  try {
    writeFileSync(LOG_FILE, "", { mode: 384 });
  } catch {
    writeFileSync(LOG_FILE, "");
  }
  try {
    chmodSync(LOG_FILE, 384);
  } catch {}
}
function log(tag, data = {}) {
  const ts = new Date().toISOString();
  const payload = Object.keys(data).length > 0 ? " " + Object.entries(data).map(([k, v]) => `${k}=${typeof v === "string" ? v : JSON.stringify(v)}`).join(" ") : "";
  appendFileSync(LOG_FILE, `${ts} [${tag}]${payload}
`);
}
function logToast(tag, toast) {
  log(tag, { toast_message: toast.message, toast_variant: toast.variant, toast_duration: toast.duration });
}
function getConfigPath() {
  const base = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  return join(base, "opencode", "copilot-meter.json");
}
function readConfig() {
  try {
    return JSON.parse(readFileSync(getConfigPath(), "utf8"));
  } catch {
    return {};
  }
}
function getCopilotToken() {
  try {
    const base = process.env.XDG_DATA_HOME || join(homedir(), ".local", "share");
    const raw = readFileSync(join(base, "opencode", "auth.json"), "utf8");
    const data = JSON.parse(raw);
    const entry = data["github-copilot-enterprise"] || data["github-copilot"];
    return entry?.refresh ?? "";
  } catch {
    return "";
  }
}
async function fetchQuotaRemaining() {
  const config = readConfig();
  const endpoint = config.quota_endpoint || "";
  if (!endpoint) {
    log("quota", { status: "skipped", reason: "no endpoint configured" });
    return null;
  }
  const token = getCopilotToken();
  if (!token) {
    log("quota", { status: "skipped", reason: "no copilot token found" });
    return null;
  }
  try {
    const res = await fetch(endpoint, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" }
    });
    if (!res.ok) {
      log("quota", { status: "error", httpStatus: res.status });
      return null;
    }
    const data = await res.json();
    const snap = data?.quota_snapshots?.premium_interactions;
    if (!snap) {
      log("quota", { status: "error", reason: "no premium_interactions in response" });
      return null;
    }
    const remaining = snap.quota_remaining ?? snap.remaining;
    const entitlement = snap.entitlement;
    const pct = snap.percent_remaining;
    const remainStr = Number.isInteger(remaining) ? String(remaining) : remaining.toFixed(1);
    const result = `quota: ${remainStr}/${entitlement} (${pct?.toFixed(1)}%)`;
    log("quota", { status: "ok", remaining, entitlement, pct });
    return result;
  } catch (e) {
    log("quota", { status: "error", error: String(e) });
    return null;
  }
}
function emptyTokens() {
  return { input: 0, output: 0, reasoning: 0, cacheRead: 0, cacheWrite: 0 };
}
function fmt(n) {
  if (n >= 1e6)
    return (n / 1e6).toFixed(1) + "M";
  if (n >= 1000)
    return (n / 1000).toFixed(1) + "k";
  return String(n);
}
var currentSessionID = "";
var CopilotMeterPlugin = async (ctx) => {
  const client = ctx.client;
  rotateLog();
  log("plugin.loaded");
  let turn = {
    calls: 0,
    steps: 0,
    reasons: {},
    tokens: emptyTokens(),
    tools: [],
    model: ""
  };
  function resetTurn() {
    turn = { calls: 0, steps: 0, reasons: {}, tokens: emptyTokens(), tools: [], model: "" };
  }
  function showToast(tag, toast) {
    logToast(tag, toast);
    client.tui.showToast({ body: toast }).catch(() => {});
  }
  async function printTurnSummary() {
    const t = turn.tokens;
    const totalTokens = t.input + t.output + t.reasoning + t.cacheRead;
    if (totalTokens === 0) {
      log("summary.skip", { reason: "zero tokens" });
      return;
    }
    log("summary.turn_state", {
      calls: turn.calls,
      steps: turn.steps,
      reasons: turn.reasons,
      tokens: turn.tokens,
      tools: turn.tools,
      model: turn.model
    });
    const parts = [];
    if (turn.model)
      parts.push(turn.model);
    parts.push(`${turn.calls} call${turn.calls !== 1 ? "s" : ""}`);
    parts.push(`${fmt(t.input)}→${fmt(t.output)}`);
    const quota = await fetchQuotaRemaining();
    if (quota)
      parts.push(quota);
    const message = parts.join(" | ");
    showToast("toast.summary", {
      title: "copilot-meter",
      message,
      variant: "info",
      duration: 30000
    });
  }
  let summaryTimer = null;
  const SUMMARY_DEBOUNCE_MS = 300;
  function scheduleSummary() {
    cancelSummary();
    summaryTimer = setTimeout(async () => {
      summaryTimer = null;
      log("summary.debounce_fired");
      await printTurnSummary();
      currentSessionID = "";
    }, SUMMARY_DEBOUNCE_MS);
  }
  function cancelSummary() {
    if (summaryTimer) {
      clearTimeout(summaryTimer);
      summaryTimer = null;
    }
  }
  return {
    "chat.message": async (input) => {
      const sessionID = input.sessionID ?? "";
      if (currentSessionID && sessionID !== currentSessionID) {
        log("hook.chat.message", { action: "skip", reason: "sub-agent session", sessionID, currentSessionID });
        return;
      }
      currentSessionID = sessionID;
      log("hook.chat.message", { sessionID: currentSessionID });
      cancelSummary();
      resetTurn();
    },
    "chat.headers": async (input, output) => {
      const agent = input.agent;
      const hidden = agent?.hidden === true;
      const agentName = typeof agent === "string" ? agent : agent?.name ?? "";
      if (hidden) {
        log("hook.chat.headers", { action: "skip", reason: "hidden agent", agent: agentName });
        return;
      }
      const provider = input.provider?.info?.id || input.model?.providerID || "";
      const model = input.model?.id ?? "unknown";
      const label = provider ? `${provider}/${model}` : model;
      const isCopilot = provider.includes("github-copilot");
      const initiatorOverride = output.headers["x-initiator"] || undefined;
      const initiator = initiatorOverride ?? (isCopilot ? turn.calls === 1 ? "user" : "agent" : undefined);
      log("hook.chat.headers", {
        provider,
        model,
        label,
        isCopilot,
        calls: turn.calls,
        initiatorOverride: initiatorOverride ?? "none",
        initiator: initiator ?? "n/a",
        agent: agentName
      });
      const isPremium = isCopilot && initiator === "user";
      if (!isPremium) {
        const config = readConfig();
        const noiseMode = config.noise_mode === true;
        if (!noiseMode) {
          log("hook.chat.headers", { action: "suppress_toast", reason: "non-premium, noise_mode=false" });
          return;
        }
      }
      const parts = [];
      if (isCopilot) {
        parts.push(initiator === "user" ? "\uD83D\uDCB0 [premium]" : "[agent]");
      }
      parts.push(label);
      if (agentName)
        parts.push(`(${agentName})`);
      showToast("toast.call", {
        title: "copilot-meter",
        message: parts.join(" "),
        variant: isPremium ? "warning" : "info",
        duration: 5000
      });
    },
    "chat.params": async (input) => {
      const agent = input.agent;
      const agentName = agent?.name ?? "unknown";
      const hidden = agent?.hidden === true;
      if (hidden) {
        log("hook.chat.params", { action: "skip", reason: "hidden agent", agent: agentName, model: input.model?.id });
        return;
      }
      turn.calls++;
      if (input.provider?.info?.id) {
        turn.model = `${input.provider.info.id}/${input.model.id}`;
      } else if (input.model?.id) {
        turn.model = input.model.id;
      }
      log("hook.chat.params", {
        agent: agentName,
        model: input.model?.id,
        "turn.calls": turn.calls,
        "turn.model": turn.model
      });
    },
    "tool.execute.after": async (input) => {
      turn.tools.push(input.tool);
      log("hook.tool.execute.after", { tool: input.tool, "turn.tools_count": turn.tools.length });
    },
    event: async ({ event }) => {
      if (event.type === "message.part.updated") {
        const part = event.properties?.part;
        if (part?.type === "step-finish") {
          turn.steps++;
          const reason = part.reason ?? "unknown";
          turn.reasons[reason] = (turn.reasons[reason] ?? 0) + 1;
          const tokens = part.tokens;
          turn.tokens.input += tokens.input ?? 0;
          turn.tokens.output += tokens.output ?? 0;
          turn.tokens.reasoning += tokens.reasoning ?? 0;
          turn.tokens.cacheRead += tokens.cache?.read ?? 0;
          turn.tokens.cacheWrite += tokens.cache?.write ?? 0;
          log("event.step-finish", {
            step: turn.steps,
            reason,
            input: tokens.input,
            output: tokens.output,
            reasoning: tokens.reasoning ?? 0,
            cacheRead: tokens.cache?.read ?? 0,
            cacheWrite: tokens.cache?.write ?? 0,
            "turn.tokens.input": turn.tokens.input,
            "turn.tokens.output": turn.tokens.output
          });
        }
      }
      if (event.type === "session.idle") {
        const idleSessionID = event.properties?.sessionID;
        if (!idleSessionID || idleSessionID !== currentSessionID) {
          log("event.session.idle", {
            action: "skip",
            reason: idleSessionID ? "non-root session" : "no sessionID",
            idleSessionID: idleSessionID ?? "none",
            currentSessionID
          });
          return;
        }
        log("event.session.idle", { action: "schedule_summary", sessionID: idleSessionID });
        scheduleSummary();
      }
      if (event.type === "session.status") {
        const props = event.properties;
        if (props?.status?.type === "busy" && props?.sessionID === currentSessionID) {
          if (summaryTimer) {
            log("event.session.status", { action: "cancel_summary", reason: "session busy again" });
            cancelSummary();
          }
        }
      }
    }
  };
};
export {
  CopilotMeterPlugin
};
