import { definePlugin } from "@opencode-ai/plugin"
import { handleToolAfter } from "./speckit-hook"
import { mkdirSync, symlinkSync, existsSync, readlinkSync, readdirSync, readFileSync, rmSync, unlinkSync } from "fs"
import { join, dirname } from "path"
import { fileURLToPath } from "url"
import { execSync } from "child_process"
export { classify, type SignalResult } from "./signals"

const __dirname = dirname(fileURLToPath(import.meta.url))
const PACKAGE_ROOT = join(__dirname, "..")
const COMMANDS_SRC = join(PACKAGE_ROOT, "commands")
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

export default definePlugin({
  name: "devils-council",
  hooks: {
    "session.created": async (_ctx) => {
      ensureCommandSymlinks()

      const installed = getInstalledVersion()
      const latest = getLatestVersion()
      if (latest && installed !== latest) {
        invalidateCache()
        console.error(
          `[devils-council] Update available: ${installed} → ${latest}. Restart session to activate.`
        )
      }
    },
    "tool.execute.before": async (_ctx) => {},
    "tool.execute.after": async (ctx) => {
      const trigger = handleToolAfter({ tool: ctx.tool, result: ctx.result })
      if (trigger && ctx.suggest) {
        ctx.suggest(`@${trigger.agent} ${trigger.artifact.slice(0, 200)}...`)
      }
    },
  },
})
