import { definePlugin } from "@opencode-ai/plugin"
import { handleToolAfter } from "./speckit-hook"
import { mkdirSync, symlinkSync, existsSync, readlinkSync } from "fs"
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
    const demoSrc = join(COMMANDS_SRC, "demo.md")
    if (!existsSync(demoSrc)) return

    mkdirSync(GLOBAL_COMMANDS_DIR, { recursive: true })
    const demoLink = join(GLOBAL_COMMANDS_DIR, "devils-council-demo.md")

    if (existsSync(demoLink)) {
      // Verify existing link points to our source
      try {
        const target = readlinkSync(demoLink)
        if (target === demoSrc) return // already correct
      } catch {
        // not a symlink, skip
        return
      }
    }

    symlinkSync(demoSrc, demoLink)
  } catch {
    // Non-fatal — command just won't be available
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
