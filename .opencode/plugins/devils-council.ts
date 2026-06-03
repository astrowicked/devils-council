import { handleToolAfter } from "./speckit-hook"
import { mkdirSync, symlinkSync, existsSync, readlinkSync, readdirSync, readFileSync, rmSync, unlinkSync } from "fs"
import { join, dirname } from "path"
import { fileURLToPath } from "url"
import { execSync } from "child_process"
export { classify, type SignalResult } from "./signals"

const __dirname = dirname(fileURLToPath(import.meta.url))
const PACKAGE_ROOT = join(__dirname, "..")
const COMMANDS_SRC = join(PACKAGE_ROOT, "commands")
const PRESETS_PATH = join(PACKAGE_ROOT, "lib", "model-presets.json")
const PERSONA_META_DIR = join(PACKAGE_ROOT, "persona-metadata")
const GLOBAL_COMMANDS_DIR = join(
  process.env.HOME || process.env.USERPROFILE || "~",
  ".config",
  "opencode",
  "commands",
)
const CACHE_DIR = join(
  process.env.HOME || process.env.USERPROFILE || "~",
  ".cache",
  "opencode",
  "packages",
  "devils-council-opencode@latest",
)

function getInstalledVersion(): string {
  try {
    const pkg = JSON.parse(readFileSync(join(PACKAGE_ROOT, "package.json"), "utf-8"))
    return pkg.version || "0.0.0"
  } catch {
    return "0.0.0"
  }
}

function getLatestVersion(): string | null {
  try {
    const result = execSync("npm info devils-council-opencode version", {
      encoding: "utf-8",
      timeout: 5000,
      stdio: ["pipe", "pipe", "pipe"],
    })
    return result.trim()
  } catch {
    return null
  }
}

function invalidateCache() {
  try {
    if (existsSync(GLOBAL_COMMANDS_DIR)) {
      const links = readdirSync(GLOBAL_COMMANDS_DIR).filter((f) => f.startsWith("devils-council-"))
      for (const link of links) {
        try { unlinkSync(join(GLOBAL_COMMANDS_DIR, link)) } catch { /* noop */ }
      }
    }
    if (existsSync(CACHE_DIR)) {
      rmSync(CACHE_DIR, { recursive: true })
    }
  } catch { /* non-fatal */ }
}

function ensureCommandSymlinks() {
  try {
    if (!existsSync(COMMANDS_SRC)) return
    mkdirSync(GLOBAL_COMMANDS_DIR, { recursive: true })

    const commands = readdirSync(COMMANDS_SRC).filter((f) => f.endsWith(".md"))

    for (const cmd of commands) {
      const src = join(COMMANDS_SRC, cmd)
      const linkName = `devils-council-${cmd}`
      const linkPath = join(GLOBAL_COMMANDS_DIR, linkName)

      if (existsSync(linkPath)) {
        try {
          const target = readlinkSync(linkPath)
          if (target === src) continue
        } catch {
          continue
        }
      }

      symlinkSync(src, linkPath)
    }
  } catch { /* non-fatal */ }
}

type TierDefault = { model?: string; variant?: string }

// v1.3: per-persona model defaults. Reads the active preset + each persona's
// model_tier sidecar, then per-field guarded-injects agent.<name>.{model,variant}
// into the resolved config. The hook receives config with the user's
// opencode.json already merged, so guarding on absence lets user overrides win.
// Built into a local map and assigned once (atomic); the whole thing is wrapped
// so any failure falls through to the session model rather than breaking the session.
// NOTE (T008, deferred): injected model IDs are not yet validated against the
// provider's available-models list — that needs the SDK client (function-shape
// plugin). Until then a misconfigured preset model can 403 at spawn time.
function injectModelDefaults(cfg: { agent?: Record<string, TierDefault> }) {
  try {
    const preset = (process.env.DEVILS_COUNCIL_MODEL_PRESET || "").trim().toLowerCase()
    if (!preset) {
      console.error(
        "[devils-council] per-persona model tiering is available but off. " +
        "Set DEVILS_COUNCIL_MODEL_PRESET=bedrock|cheap to enable."
      )
      return
    }
    if (preset === "off") return
    if (preset !== "bedrock" && preset !== "cheap") {
      console.error(`[devils-council] unknown DEVILS_COUNCIL_MODEL_PRESET='${preset}' (expected bedrock|cheap|off); tiering off.`)
      return
    }

    const presets = JSON.parse(readFileSync(PRESETS_PATH, "utf-8"))
    const tierMap: Record<string, TierDefault> = presets[preset]
    if (!tierMap) {
      console.error(`[devils-council] preset '${preset}' not found in model-presets.json; tiering off.`)
      return
    }

    // Resolve each persona's desired default from its model_tier sidecar.
    const desired: Record<string, TierDefault> = {}
    for (const f of readdirSync(PERSONA_META_DIR)) {
      if (!f.endsWith(".yml")) continue
      const name = f.replace(/\.yml$/, "")
      const text = readFileSync(join(PERSONA_META_DIR, f), "utf-8")
      const m = text.match(/^model_tier:\s*(\S+)/m)
      if (!m) continue // classifier (and anything untagged) is exempt
      const td = tierMap[m[1]]
      if (td && td.model) desired[name] = td
    }

    // Per-field guarded merge into a LOCAL copy; assign once at the end (atomic).
    const agent: Record<string, TierDefault> = { ...(cfg.agent || {}) }
    for (const [name, td] of Object.entries(desired)) {
      const merged: TierDefault = { ...(agent[name] || {}) }
      if (!merged.model && td.model) merged.model = td.model
      if (!merged.variant && td.variant) merged.variant = td.variant
      agent[name] = merged
    }
    cfg.agent = agent
  } catch (e) {
    // Fail safe: never break session startup. Log one line, leave config unmutated.
    console.error(`[devils-council] model tiering skipped (config hook error): ${(e as Error).message}`)
  }
}

// v1.3: migrated from the custom definePlugin({hooks}) shape to the real
// @opencode-ai/plugin function shape (input => Hooks). The function shape is what
// fires the `config` hook (the definePlugin shape silently ignores it) and exposes
// `input.client` for future model-availability validation (T008). Hook keys:
//   - config: per-persona model default injection
//   - event: session lifecycle (the real API has no `session.created` key; we filter)
//   - tool.execute.before/after: unchanged keys; .after now uses (input, output) with
//     the result in output.output and surfaces the speckit suggestion by appending to it
//     (the real API has no ctx.suggest).
type ToolAfterInput = { tool: string; sessionID?: string; callID?: string; args?: unknown }
type ToolAfterOutput = { title?: string; output?: string; metadata?: unknown }

export const DevilsCouncilPlugin = async (_input: unknown) => {
  return {
    config: async (cfg: { agent?: Record<string, TierDefault> }) => {
      injectModelDefaults(cfg)
    },
    event: async ({ event }: { event: { type?: string } }) => {
      if (event && event.type === "session.created") {
        ensureCommandSymlinks()
        const installed = getInstalledVersion()
        const latest = getLatestVersion()
        if (latest && installed !== latest) {
          invalidateCache()
          console.error(
            `[devils-council] Update available: ${installed} → ${latest}. Restart session to activate.`
          )
        }
      }
    },
    "tool.execute.before": async (_input: ToolAfterInput, _output: { args?: unknown }) => {},
    "tool.execute.after": async (input: ToolAfterInput, output: ToolAfterOutput) => {
      try {
        const trigger = handleToolAfter({ tool: input.tool, result: output.output })
        if (trigger && typeof output.output === "string") {
          output.output +=
            `\n\n[DEVILS-COUNCIL] Plan detected. Run:\n${trigger.command}\n` +
            `No additional context needed — the command handles everything.`
        }
      } catch {
        /* non-fatal: never break tool execution */
      }
    },
  }
}

export default DevilsCouncilPlugin
