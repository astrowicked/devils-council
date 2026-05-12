export interface SignalResult {
  version: number
  triggered_personas: string[]
  trigger_reasons: Record<string, string[]>
}

type Detector = (text: string, filenameHint?: string) => string | null

const LOCKFILE_PATTERN = /package-lock\.json|yarn\.lock|go\.sum|pnpm-lock\.yaml/

// --- Security Reviewer detectors ---

const securityDetectors: Detector[] = [
  (text) => {
    if (/['"\/](login|auth|oauth)['"\/\s,)]/.test(text) || /\/(login|auth|oauth)\b/.test(text))
      return "Auth/login/OAuth path pattern detected"
    return null
  },
  (text) => {
    if (/\b(crypto|bcrypt|argon2|jose|libsodium|nacl)\b/.test(text))
      return "Cryptographic library import detected"
    return null
  },
  (text) => {
    if (/process\.env\.\w*(SECRET|KEY|TOKEN)/.test(text))
      return "Secret environment variable access detected"
    return null
  },
  (_text, filenameHint) => {
    if (filenameHint && LOCKFILE_PATTERN.test(filenameHint))
      return "Lockfile modification detected"
    return null
  },
]

// --- FinOps Auditor detectors ---

const finopsDetectors: Detector[] = [
  (text) => {
    if (/\b(boto3|aws[_-]sdk)\b|@aws-sdk\/client-/.test(text))
      return "AWS SDK import detected"
    return null
  },
  (text) => {
    if (/resource\s+"aws_/.test(text) || /new\s+\w*(Stack|Construct|CfnResource)/.test(text) || /from\s+['"]aws_cdk/.test(text) || /from\s+['"]@aws-cdk/.test(text))
      return "Cloud resource declaration (Terraform/CDK) detected"
    return null
  },
  (text) => {
    if (/\b(autoscaling|HorizontalPodAutoscaler)\b|replicas:\s*\d/.test(text))
      return "Autoscaling/HPA/replica configuration detected"
    return null
  },
  (text) => {
    if (/\b(storageClassName|StorageClass)\b/.test(text))
      return "Storage class declaration detected"
    return null
  },
]

// --- Air-Gap Reviewer detectors ---

const airgapDetectors: Detector[] = [
  (_text, filenameHint) => {
    if (filenameHint && LOCKFILE_PATTERN.test(filenameHint))
      return "Lockfile modification detected (dependency update)"
    return null
  },
  (text) => {
    const fetchMatch = text.match(/fetch\s*\(\s*['"`]([^'"`]+)['"`]/)
    if (fetchMatch && !/localhost|127\.0\.0\.1|0\.0\.0\.0/.test(fetchMatch[1]))
      return `External network egress via fetch() to ${fetchMatch[1]}`
    const axiosMatch = text.match(/axios\.(get|post|put|delete|patch)\s*\(\s*['"`]([^'"`]+)['"`]/)
    if (axiosMatch && !/localhost|127\.0\.0\.1|0\.0\.0\.0/.test(axiosMatch[2]))
      return `External network egress via axios to ${axiosMatch[2]}`
    const requestsMatch = text.match(/requests\.(get|post|put|delete|patch)\s*\(\s*['"`]([^'"`]+)['"`]/)
    if (requestsMatch && !/localhost|127\.0\.0\.1|0\.0\.0\.0/.test(requestsMatch[2]))
      return `External network egress via requests to ${requestsMatch[2]}`
    return null
  },
  (text) => {
    if (/FROM\s+(?!scratch\b)\S+\.\S+[\/:]\S+/.test(text) || /image:\s*(?!scratch\b)\S+\.\S+[\/:]\S+/.test(text))
      return "External container image reference detected"
    return null
  },
  (text) => {
    if (/["']\s*[\^~]|>=\s*\d|:\s*["']?latest["']?/.test(text))
      return "Unpinned dependency version detected"
    return null
  },
  (text) => {
    if (/Sentry\.init|datadogRum|Mixpanel|analytics\.track/.test(text))
      return "Telemetry/analytics phone-home SDK detected"
    return null
  },
]

// --- Performance Reviewer detectors (need 2+ to trigger) ---

const performanceDetectors: Detector[] = [
  (text) => {
    if (/\b(for|while)\b[^{]*\{/s.test(text) && /\b(query|fetch|request)\s*\(/.test(text))
      return "Loop contains database/network call (potential N+1)"
    return null
  },
  (text) => {
    if (/\b(for|while)\b[\s\S]*?\b(query|select|insert|update|delete)\b/i.test(text) &&
        /\b(for|while)\b[^{]*\{[\s\S]*?\b(query|select|insert|update|delete)\b/i.test(text))
      return "SQL operation inside iteration scope"
    return null
  },
  (text) => {
    if (/\b(for|while)\b[^{]*\{[^}]*\b(for|while)\b/s.test(text))
      return "Nested iteration detected"
    return null
  },
  (text) => {
    if (/\b(for|while)\b[^{]*\{[^}]*\bnew\s+(Array|Object|Map|Set|WeakMap|WeakSet)\b/s.test(text))
      return "Per-iteration allocation inside loop"
    return null
  },
]

function runDetectors(detectors: Detector[], text: string, filenameHint?: string): string[] {
  const reasons: string[] = []
  for (const detect of detectors) {
    const reason = detect(text, filenameHint)
    if (reason) reasons.push(reason)
  }
  return reasons
}

export function classify(text: string, filenameHint?: string): SignalResult {
  const trigger_reasons: Record<string, string[]> = {}

  const securityReasons = runDetectors(securityDetectors, text, filenameHint)
  if (securityReasons.length >= 1) trigger_reasons["security-reviewer"] = securityReasons

  const finopsReasons = runDetectors(finopsDetectors, text, filenameHint)
  if (finopsReasons.length >= 1) trigger_reasons["finops-auditor"] = finopsReasons

  const airgapReasons = runDetectors(airgapDetectors, text, filenameHint)
  if (airgapReasons.length >= 1) trigger_reasons["air-gap-reviewer"] = airgapReasons

  const perfReasons = runDetectors(performanceDetectors, text, filenameHint)
  if (perfReasons.length >= 2) trigger_reasons["performance-reviewer"] = perfReasons

  return {
    version: 1,
    triggered_personas: Object.keys(trigger_reasons),
    trigger_reasons,
  }
}
