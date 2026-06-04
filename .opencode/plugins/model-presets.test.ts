import { test } from "node:test"
import assert from "node:assert/strict"
import { injectModelDefaults } from "./devils-council.ts"

// Unit tests for the v1.3 per-persona model injection logic.
// These are CI-safe: pure function calls against the built preset + sidecar
// files (no live model spawns). Live override-precedence verification lives in
// the nightly cheap-preset round-trip (FR-12), not here.

type Agent = Record<string, { model?: string; variant?: string }>

function withPreset(preset: string | undefined, fn: () => void) {
  const prev = process.env.DEVILS_COUNCIL_MODEL_PRESET
  if (preset === undefined) delete process.env.DEVILS_COUNCIL_MODEL_PRESET
  else process.env.DEVILS_COUNCIL_MODEL_PRESET = preset
  try { fn() } finally {
    if (prev === undefined) delete process.env.DEVILS_COUNCIL_MODEL_PRESET
    else process.env.DEVILS_COUNCIL_MODEL_PRESET = prev
  }
}

test("off injects nothing", () => {
  withPreset("off", () => {
    const cfg: { agent?: Agent } = {}
    injectModelDefaults(cfg)
    assert.equal(cfg.agent, undefined)
  })
})

test("unknown preset injects nothing", () => {
  withPreset("nonsense", () => {
    const cfg: { agent?: Agent } = {}
    injectModelDefaults(cfg)
    assert.equal(cfg.agent, undefined)
  })
})

test("cheap preset maps tiers to models (deep + workhorse), classifier exempt", () => {
  withPreset("cheap", () => {
    const cfg: { agent?: Agent } = {}
    injectModelDefaults(cfg)
    assert.ok(cfg.agent, "agent map populated")
    // deep-reasoning
    assert.equal(cfg.agent!["council-chair"]?.model, "opencode/minimax-m3-free")
    assert.equal(cfg.agent!["security-reviewer"]?.model, "opencode/minimax-m3-free")
    // workhorse
    assert.equal(cfg.agent!["staff-engineer"]?.model, "opencode/deepseek-v4-flash-free")
    assert.equal(cfg.agent!["sre"]?.model, "opencode/deepseek-v4-flash-free")
    // classifier is exempt (no model_tier => not injected)
    assert.equal(cfg.agent!["artifact-classifier"], undefined)
  })
})

test("per-field guard: user model override wins", () => {
  withPreset("cheap", () => {
    const cfg: { agent?: Agent } = { agent: { "council-chair": { model: "user/custom" } } }
    injectModelDefaults(cfg)
    assert.equal(cfg.agent!["council-chair"].model, "user/custom", "user model preserved")
  })
})

test("per-field guard: variant-only user override preserved, model still injected", () => {
  withPreset("cheap", () => {
    const cfg: { agent?: Agent } = { agent: { "council-chair": { variant: "high" } } }
    injectModelDefaults(cfg)
    assert.equal(cfg.agent!["council-chair"].variant, "high", "user variant preserved")
    assert.equal(cfg.agent!["council-chair"].model, "opencode/minimax-m3-free", "model injected")
  })
})

test("bedrock preset sets variant:max on deep-reasoning", () => {
  withPreset("bedrock", () => {
    const cfg: { agent?: Agent } = {}
    injectModelDefaults(cfg)
    assert.equal(cfg.agent!["council-chair"]?.variant, "max")
    assert.ok(cfg.agent!["council-chair"]?.model?.includes("opus"))
    // workhorse has no variant
    assert.equal(cfg.agent!["staff-engineer"]?.variant, undefined)
  })
})

test("budget preset maps every tier to big-pickle, classifier exempt, no variant", () => {
  withPreset("budget", () => {
    const cfg: { agent?: Agent } = {}
    injectModelDefaults(cfg)
    assert.ok(cfg.agent, "agent map populated")
    // deep-reasoning + workhorse both resolve to big-pickle
    assert.equal(cfg.agent!["council-chair"]?.model, "opencode/big-pickle")
    assert.equal(cfg.agent!["security-reviewer"]?.model, "opencode/big-pickle")
    assert.equal(cfg.agent!["staff-engineer"]?.model, "opencode/big-pickle")
    // no variant on the budget preset
    assert.equal(cfg.agent!["council-chair"]?.variant, undefined)
    // classifier exempt
    assert.equal(cfg.agent!["artifact-classifier"], undefined)
  })
})
