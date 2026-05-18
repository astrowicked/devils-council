import { readdirSync, statSync, existsSync } from "node:fs"
import { join } from "node:path"

export interface ToolAfterContext {
  tool: string
  result?: unknown
}

export interface TriggerAction {
  command: string
  path: string
}

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

function extractPathFromResult(result: string): string | null {
  // Try common patterns: "wrote plan.md", "created specs/foo/plan.md", path in JSON
  const pathMatch = result.match(/(?:specs\/[^\s"']+?plan\.md|\.specify\/[^\s"']+?\.md)/i)
  if (pathMatch) return pathMatch[0]

  // Try: any .md path that contains "plan"
  const mdMatch = result.match(/([^\s"']+plan[^\s"']*\.md)/i)
  if (mdMatch) return mdMatch[1]

  return null
}

function findLatestPlanFile(): string | null {
  const dirs = ["specs", ".specify"]
  let latest: { path: string; mtime: number } | null = null

  for (const dir of dirs) {
    try {
      if (!existsSync(dir)) continue
      walkForPlans(dir, (filePath: string, mtime: number) => {
        if (!latest || mtime > latest.mtime) {
          latest = { path: filePath, mtime }
        }
      })
    } catch {
      continue
    }
  }

  return latest ? latest.path : null
}

function walkForPlans(dir: string, cb: (path: string, mtime: number) => void, depth = 0): void {
  if (depth > 4) return
  try {
    const entries = readdirSync(dir)
    for (const entry of entries) {
      const full = join(dir, entry)
      try {
        const st = statSync(full)
        if (st.isDirectory()) {
          walkForPlans(full, cb, depth + 1)
        } else if (entry.toLowerCase().includes("plan") && entry.endsWith(".md")) {
          cb(full, st.mtimeMs)
        }
      } catch { continue }
    }
  } catch { /* dir not readable */ }
}

export function handleToolAfter(ctx: ToolAfterContext): TriggerAction | null {
  if (!isSpeckitPlanTool(ctx.tool)) {
    return null
  }

  const resultText = extractResultText(ctx.result)
  if (resultText.length < MIN_RESULT_LENGTH) {
    return null
  }

  // Try to get path from result first, fall back to filesystem scan
  let planPath = extractPathFromResult(resultText)
  if (!planPath) {
    planPath = findLatestPlanFile()
  }

  if (!planPath) {
    return null
  }

  return {
    command: `/devils-council:review ${planPath} --type=plan`,
    path: planPath,
  }
}

export interface TriggerAction {
  command: string
  path: string
}

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

function extractPathFromResult(result: string): string | null {
  // Try common patterns: "wrote plan.md", "created specs/foo/plan.md", path in JSON
  const pathMatch = result.match(/(?:specs\/[^\s"']+?plan\.md|\.specify\/[^\s"']+?\.md)/i)
  if (pathMatch) return pathMatch[0]

  // Try: any .md path that contains "plan" 
  const mdMatch = result.match(/([^\s"']+plan[^\s"']*\.md)/i)
  if (mdMatch) return mdMatch[1]

  return null
}

function findLatestPlanFile(): string | null {
  const dirs = ["specs", ".specify"]
  let latest: { path: string; mtime: number } | null = null

  for (const dir of dirs) {
    try {
      walkForPlans(dir, (filePath, mtime) => {
        if (!latest || mtime > latest.mtime) {
          latest = { path: filePath, mtime }
        }
      })
    } catch {
      continue
    }
  }

  return latest?.path ?? null
}

function walkForPlans(dir: string, cb: (path: string, mtime: number) => void, depth = 0): void {
  if (depth > 4) return
  try {
    const entries = readdirSync(dir, { withFileTypes: true })
    for (const entry of entries) {
      const full = join(dir, entry.name)
      if (entry.isDirectory()) {
        walkForPlans(full, cb, depth + 1)
      } else if (entry.name.toLowerCase().includes("plan") && entry.name.endsWith(".md")) {
        const st = statSync(full)
        cb(full, st.mtimeMs)
      }
    }
  } catch { /* dir doesn't exist or not readable */ }
}

export function handleToolAfter(ctx: ToolAfterContext): TriggerAction | null {
  if (!isSpeckitPlanTool(ctx.tool)) {
    return null
  }

  const resultText = extractResultText(ctx.result)
  if (resultText.length < MIN_RESULT_LENGTH) {
    return null
  }

  // Try to get path from result first, fall back to filesystem scan
  let planPath = extractPathFromResult(resultText)
  if (!planPath) {
    planPath = findLatestPlanFile()
  }

  if (!planPath) {
    return null
  }

  return {
    command: `/devils-council:review ${planPath} --type=plan`,
    path: planPath,
  }
}
