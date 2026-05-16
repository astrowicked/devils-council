import { definePlugin } from "@opencode-ai/plugin"
import { handleToolAfter } from "./speckit-hook"
import { mkdirSync, symlinkSync, existsSync, readlinkSync, readdirSync } from "fs"
import { join, dirname } from "path"
import { fileURLToPath } from "url"
export { classify, type SignalResult } from "./signals"

const __dirname = dirname(fileURLToPath(import.meta.url))
const COMMANDS_SRC = join(__dirname, "..", "commands")
const GLOBAL_COMMANDS_DIR = join(
  process.env.HOME || process.env.USERPROFILE || "~",
  ".config",
  "opencode",
  "commands",
)

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
          if (target === src) continue // already correct
        } catch {
          continue // exists but not a symlink, skip
        }
      }

      symlinkSync(src, linkPath)
    }
  } catch {
    // Non-fatal — commands just won't be available globally
  }
}

export default definePlugin({
  name: "devils-council",
  hooks: {
    "session.created": async (_ctx) => {
      ensureCommandSymlinks()
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
