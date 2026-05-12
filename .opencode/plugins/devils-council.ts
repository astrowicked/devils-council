import { definePlugin } from "@opencode-ai/plugin"
import { handleToolAfter } from "./speckit-hook"
export { classify, type SignalResult } from "./signals"

export default definePlugin({
  name: "devils-council",
  hooks: {
    "session.created": async (_ctx) => {},
    "tool.execute.before": async (_ctx) => {},
    "tool.execute.after": async (ctx) => {
      const trigger = handleToolAfter({ tool: ctx.tool, result: ctx.result })
      if (trigger && ctx.suggest) {
        ctx.suggest(`@${trigger.agent} ${trigger.artifact.slice(0, 200)}...`)
      }
    },
  },
})
