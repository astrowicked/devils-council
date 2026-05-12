import { definePlugin } from "@opencode-ai/plugin"
export { classify, type SignalResult } from "./signals"

export default definePlugin({
  name: "devils-council",
  hooks: {
    "session.created": async (ctx) => {
      // Future: auto-classify session context
    },
    "tool.execute.before": async (ctx) => {
      // Phase 5: Speckit integration hook
    },
  },
})
