import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { classify, type SignalResult } from "./signals"

// Helper: resolve fixture path relative to repo root
const fixtureDir = join(import.meta.dirname, "..", "test-fixtures")

describe("classify() — Security Reviewer triggers", () => {
  it("triggers on auth/login path patterns", () => {
    const result = classify("app.post('/login', handler)")
    assert.ok(result.triggered_personas.includes("security-reviewer"))
    assert.ok(result.trigger_reasons["security-reviewer"].length >= 1)
  })

  it("triggers on /auth path", () => {
    const result = classify("router.get('/auth/callback', ...)")
    assert.ok(result.triggered_personas.includes("security-reviewer"))
  })

  it("triggers on /oauth path", () => {
    const result = classify("fetch('/oauth/token')")
    assert.ok(result.triggered_personas.includes("security-reviewer"))
  })

  it("triggers on crypto imports", () => {
    const result = classify("import bcrypt from 'bcrypt'\nbcrypt.hash(password)")
    assert.ok(result.triggered_personas.includes("security-reviewer"))
  })

  it("triggers on jose/argon2/libsodium/nacl imports", () => {
    for (const lib of ["jose", "argon2", "libsodium", "nacl", "crypto"]) {
      const result = classify(`import { sign } from '${lib}'`)
      assert.ok(
        result.triggered_personas.includes("security-reviewer"),
        `Expected security-reviewer for import of ${lib}`
      )
    }
  })

  it("triggers on secret env vars", () => {
    const result = classify("const key = process.env.AWS_SECRET_KEY")
    assert.ok(result.triggered_personas.includes("security-reviewer"))
  })

  it("triggers on lockfile changes via filenameHint", () => {
    const result = classify("some content", "package-lock.json")
    assert.ok(result.triggered_personas.includes("security-reviewer"))
  })
})

describe("classify() — FinOps Auditor triggers", () => {
  it("triggers on boto3 import", () => {
    const result = classify("import boto3\nfrom aws_cdk import Stack")
    assert.ok(result.triggered_personas.includes("finops-auditor"))
  })

  it("triggers on @aws-sdk/client imports", () => {
    const result = classify("import { S3Client } from '@aws-sdk/client-s3'")
    assert.ok(result.triggered_personas.includes("finops-auditor"))
  })

  it("triggers on Terraform AWS resources", () => {
    const result = classify('resource "aws_s3_bucket" "main" {\n  bucket = "my-bucket"\n}')
    assert.ok(result.triggered_personas.includes("finops-auditor"))
  })

  it("triggers on HPA/autoscaling", () => {
    const result = classify("kind: HorizontalPodAutoscaler\nspec:\n  minReplicas: 2")
    assert.ok(result.triggered_personas.includes("finops-auditor"))
  })

  it("triggers on storageClassName", () => {
    const result = classify("storageClassName: gp3-encrypted")
    assert.ok(result.triggered_personas.includes("finops-auditor"))
  })
})

describe("classify() — Air-Gap Reviewer triggers", () => {
  it("triggers on fetch to external URL", () => {
    const result = classify("fetch('https://api.datadog.com/v1/series')")
    assert.ok(result.triggered_personas.includes("air-gap-reviewer"))
  })

  it("triggers on axios to external URL", () => {
    const result = classify("axios.get('https://registry.npmjs.org/package')")
    assert.ok(result.triggered_personas.includes("air-gap-reviewer"))
  })

  it("does NOT trigger on fetch to localhost", () => {
    const result = classify("fetch('http://localhost:3000/api')")
    assert.ok(!result.triggered_personas.includes("air-gap-reviewer"))
  })

  it("triggers on external container image", () => {
    const result = classify("FROM docker.io/nginx:latest")
    assert.ok(result.triggered_personas.includes("air-gap-reviewer"))
  })

  it("triggers on unpinned deps (^ and ~)", () => {
    const result = classify('"lodash": "^4.17.21"')
    assert.ok(result.triggered_personas.includes("air-gap-reviewer"))
  })

  it("triggers on Sentry.init telemetry", () => {
    const result = classify("Sentry.init({ dsn: 'https://...' })")
    assert.ok(result.triggered_personas.includes("air-gap-reviewer"))
  })

  it("triggers on datadogRum", () => {
    const result = classify("datadogRum.init({ applicationId: '...' })")
    assert.ok(result.triggered_personas.includes("air-gap-reviewer"))
  })

  it("triggers on lockfile via filenameHint", () => {
    const result = classify("some content", "yarn.lock")
    assert.ok(result.triggered_personas.includes("air-gap-reviewer"))
  })
})

describe("classify() — Performance Reviewer triggers", () => {
  it("triggers when 2+ signals present (loop + db query)", () => {
    const code = `for (const item of items) {
  const row = db.query(\`SELECT * FROM users WHERE id = \${item.id}\`)
  results.push(row)
}`
    const result = classify(code)
    assert.ok(result.triggered_personas.includes("performance-reviewer"))
    assert.ok(result.trigger_reasons["performance-reviewer"].length >= 2)
  })

  it("does NOT trigger with only 1 signal (nested loop alone)", () => {
    const code = `for (const a of items) {
  for (const b of other) {
    combined.push(a + b)
  }
}`
    const result = classify(code)
    // Nested loop is only 1 signal — need 2+ to trigger
    // Actually nested loop is 1 signal, but in-loop allocation (push with new-ish) might not count
    // With just nested loops, we only have 1 signal
    assert.ok(!result.triggered_personas.includes("performance-reviewer"))
  })

  it("triggers with nested loop + in-loop allocation", () => {
    const code = `for (const item of items) {
  for (const sub of item.children) {
    const map = new Map()
    map.set(sub.id, sub.value)
  }
}`
    const result = classify(code)
    assert.ok(result.triggered_personas.includes("performance-reviewer"))
  })
})

describe("classify() — No triggers (clean inputs)", () => {
  it("returns empty for simple refactor code", () => {
    const result = classify("const x = a + b; // simple refactor")
    assert.deepEqual(result.triggered_personas, [])
    assert.deepEqual(result.trigger_reasons, {})
  })

  it("always returns version 1", () => {
    const result = classify("anything")
    assert.equal(result.version, 1)
  })
})

describe("classify() — Fixture-based integration tests", () => {
  it("aws-plan.md triggers finops-auditor and air-gap-reviewer", () => {
    const content = readFileSync(join(fixtureDir, "aws-plan.md"), "utf-8")
    const result = classify(content)
    assert.ok(
      result.triggered_personas.includes("finops-auditor"),
      `Expected finops-auditor, got: ${JSON.stringify(result.triggered_personas)}`
    )
    assert.ok(
      result.triggered_personas.includes("air-gap-reviewer"),
      `Expected air-gap-reviewer, got: ${JSON.stringify(result.triggered_personas)}`
    )
    // Should have reasons for each
    assert.ok(result.trigger_reasons["finops-auditor"].length >= 1)
    assert.ok(result.trigger_reasons["air-gap-reviewer"].length >= 1)
  })

  it("simple-refactor.md triggers nothing", () => {
    const content = readFileSync(join(fixtureDir, "simple-refactor.md"), "utf-8")
    const result = classify(content)
    assert.deepEqual(
      result.triggered_personas,
      [],
      `Expected no triggers, got: ${JSON.stringify(result.triggered_personas)}`
    )
  })
})

describe("classify() — Threat T-04-01: non-backtracking regex performance", () => {
  it("handles 10KB+ input in reasonable time", () => {
    const largeInput = "const x = 1;\n".repeat(1000) // ~13KB
    const start = performance.now()
    const result = classify(largeInput)
    const elapsed = performance.now() - start
    assert.ok(elapsed < 100, `classify() took ${elapsed}ms on 10KB+ input (expected <100ms)`)
    assert.equal(result.version, 1)
  })
})
