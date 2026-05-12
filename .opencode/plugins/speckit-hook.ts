export interface ToolAfterContext {
  tool: string
  result?: unknown
}

export interface TriggerAction {
  agent: string
  artifact: string
}

// Minimum chars to consider result as substantial plan content (not "ok" or status messages)
const MIN_RESULT_LENGTH = 50

function isSpeckitPlanTool(tool: string): boolean {
  const lower = tool.toLowerCase()
  return lower.startsWith("speckit") && lower.includes("plan")
}

function extractResultText(result: unknown): string {
  if (result == null) return ""
  if (typeof result === "string") return result
  try {
    return JSON.stringify(result)
  } catch {
    return String(result)
  }
}

/**
 * Detect speckit plan completion and return a trigger action for council-review.
 * Returns null for non-speckit tools or empty results (graceful degradation).
 */
export function handleToolAfter(ctx: ToolAfterContext): TriggerAction | null {
  if (!isSpeckitPlanTool(ctx.tool)) {
    return null
  }

  const artifact = extractResultText(ctx.result)
  if (artifact.length < MIN_RESULT_LENGTH) {
    return null
  }

  return {
    agent: "council-review",
    artifact,
  }
}
