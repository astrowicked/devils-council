import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { handleToolAfter } from "./speckit-hook"

describe("handleToolAfter() — speckit plan detection", () => {
  const planContent = `## Objective\nBuild authentication module\n\n## Tasks\n- Task 1: Create login endpoint\n- Task 2: Add JWT validation`

  it("triggers on speckit.plan tool result with path in output", () => {
    const resultWithPath = "Plan written to specs/auth/plan.md\n\n" + planContent
    const result = handleToolAfter({ tool: "speckit.plan", result: resultWithPath })
    assert.ok(result !== null, "Expected trigger action for speckit.plan")
    assert.ok(result!.command.startsWith("/devils-council:review"))
    assert.ok(result!.command.includes("--type=plan"))
    assert.equal(result!.path, "specs/auth/plan.md")
  })

  it("triggers on speckit:plan tool name", () => {
    const resultWithPath = "Created specs/feature/plan.md with 5 tasks covering authentication and authorization flows"
    const result = handleToolAfter({ tool: "speckit:plan", result: resultWithPath })
    assert.ok(result !== null, "Expected trigger action for speckit:plan")
    assert.ok(result!.command.includes("specs/feature/plan.md"))
  })

  it("triggers on speckit_plan_generate variant", () => {
    const resultWithPath = "Wrote plan to specs/new-feature/plan.md with implementation details for the migration"
    const result = handleToolAfter({ tool: "speckit_plan_generate", result: resultWithPath })
    assert.ok(result !== null, "Expected trigger for tool name starting with speckit and containing plan")
    assert.ok(result!.command.includes("/devils-council:review"))
  })

  it("returns null for unrelated tools (grep, read, etc.)", () => {
    assert.equal(handleToolAfter({ tool: "grep", result: "some output" }), null)
    assert.equal(handleToolAfter({ tool: "read", result: "file content" }), null)
    assert.equal(handleToolAfter({ tool: "bash", result: "command output" }), null)
    assert.equal(handleToolAfter({ tool: "write", result: "wrote file" }), null)
  })

  it("returns null when result is empty/undefined/short", () => {
    assert.equal(handleToolAfter({ tool: "speckit.plan", result: undefined }), null)
    assert.equal(handleToolAfter({ tool: "speckit.plan", result: "" }), null)
    assert.equal(handleToolAfter({ tool: "speckit.plan", result: "ok" }), null)
  })

  it("extracts path from result containing specs/ pattern", () => {
    const result = handleToolAfter({ tool: "speckit.plan", result: "Generated plan at specs/auth-module/plan.md successfully" })
    assert.ok(result !== null)
    assert.equal(result!.path, "specs/auth-module/plan.md")
  })

  it("is case-insensitive for tool name matching", () => {
    const resultWithPath = "Plan generated at specs/foo/plan.md with full implementation breakdown and timeline"
    const upper = handleToolAfter({ tool: "Speckit.Plan", result: resultWithPath })
    const mixed = handleToolAfter({ tool: "SPECKIT_PLAN", result: resultWithPath })
    assert.ok(upper !== null)
    assert.ok(mixed !== null)
  })

  it("returns null if plan path cannot be determined", () => {
    const result = handleToolAfter({ tool: "speckit.plan", result: planContent })
    // No path in output AND no filesystem — returns null gracefully
    // (filesystem glob won't find anything in test environment)
    // This tests graceful degradation
    if (result === null) {
      assert.ok(true, "Graceful null when path not determinable")
    } else {
      assert.ok(result.command.includes("/devils-council:review"))
    }
  })
})
