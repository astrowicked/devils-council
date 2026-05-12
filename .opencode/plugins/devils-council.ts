import { definePlugin } from "@opencode-ai/plugin"

export default definePlugin({
  name: "devils-council",
  hooks: {
    "session.created": async (ctx) => {
      // Phase 3: Signal detection + persona selection
    },
    "tool.execute.before": async (ctx) => {
      // Phase 5: Speckit integration hook
    },
  },
})
