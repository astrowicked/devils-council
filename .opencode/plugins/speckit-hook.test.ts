import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { handleToolAfter } from "./speckit-hook"

describe("handleToolAfter() — speckit plan detection", () => {
  const planContent = `## Objective\nBuild authentication module\n\n## Tasks\n- Task 1: Create login endpoint\n- Task 2: Add JWT validation`

  it("triggers on speckit.plan tool result", () => {
    const result = handleToolAfter({ tool: "speckit.plan", result: planContent })
    assert.ok(result !== null, "Expected trigger action for speckit.plan")
    assert.equal(result!.agent, "council-review")
    assert.ok(result!.artifact.length > 0, "Artifact should contain plan text")
  })

  it("triggers on speckit:plan tool name", () => {
    const result = handleToolAfter({ tool: "speckit:plan", result: planContent })
    assert.ok(result !== null, "Expected trigger action for speckit:plan")
    assert.equal(result!.agent, "council-review")
  })

  it("triggers on speckit_plan_generate variant", () => {
    const result = handleToolAfter({ tool: "speckit_plan_generate", result: planContent })
    assert.ok(result !== null, "Expected trigger for tool name starting with speckit and containing plan")
    assert.equal(result!.agent, "council-review")
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

  it("extracts artifact text from string result", () => {
    const result = handleToolAfter({ tool: "speckit.plan", result: planContent })
    assert.ok(result !== null)
    assert.equal(result!.artifact, planContent)
  })

  it("extracts artifact from object result via JSON.stringify", () => {
    const objResult = { plan: "Build authentication with JWT tokens and refresh rotation", tasks: ["login", "validate"] }
    const result = handleToolAfter({ tool: "speckit.plan", result: objResult })
    assert.ok(result !== null, "Object result should be stringified and treated as artifact")
    assert.equal(result!.artifact, JSON.stringify(objResult))
  })

  it("is case-insensitive for tool name matching", () => {
    const result = handleToolAfter({ tool: "Speckit.Plan", result: planContent })
    assert.ok(result !== null, "Tool matching should be case-insensitive")
    assert.equal(result!.agent, "council-review")
  })
})
