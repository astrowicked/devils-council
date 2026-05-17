---
persona: staff-engineer
run_id: 20260516T153219Z-demo-plan
findings:
- id: staff-engineer-c7455e54
  target: '### Task 2: Template Engine'
  claim: Half of this task list is a product backlog for a standalone templating product, not a prerequisite for shipping a notification pipeline.
  evidence: 'A/B testing framework for template variants with statistical significance tracking

    '
  ask: Delete the A/B testing framework, template dependency graph, template preview API, and Liquid fallback parser. Ship Handlebars-from-S3 with a locale folder convention. Add the rest only when someone
    asks for it.
  severity: major
  category: yagni
- id: staff-engineer-9110261d
  target: '### Task 6: Multi-Region Active-Active Deployment'
  claim: Active-active across two regions with MirrorMaker 2 and PostgreSQL logical replication is a 6-month infrastructure project being allocated one week in a plan whose stated problem is inline p99
    latency spikes.
  evidence: '- Week 4: Task 6 (multi-region)

    '
  ask: Ship single-region. Add multi-region as a separate RFC after you have production traffic proving the single-region service meets its SLOs.
  severity: major
  category: scope-creep
- id: staff-engineer-26300434
  target: '## Risks & Mitigations'
  claim: Every mitigation is a quoted platitude restating the mechanism name rather than naming the observable condition and human action that follows when the mechanism fails.
  evidence: '| Kafka consumer lag causes delayed notifications | "Auto-scaling is configured" |

    '
  ask: 'Replace each cell with: threshold that fires an alert, who responds, and what the runbook says to do when the mitigation itself is insufficient.'
  severity: major
  category: correctness
- id: staff-engineer-d03f6c80
  target: '### Task 2: Template Engine'
  claim: Two template parsers (Handlebars + Liquid) in the same delivery path means two sets of security surface, two caching strategies, and zero explanation of which callers need Liquid.
  evidence: 'Liquid fallback parser for legacy templates

    '
  ask: Name the caller that requires Liquid or delete it. If legacy templates exist, migrate them to Handlebars as a prerequisite task.
  severity: minor
  category: complexity
- id: staff-engineer-4ca56380
  target: '## Timeline'
  claim: Tasks 1-3 in two weeks requires standing up Kafka consumer with exactly-once, the full template engine, three delivery channel integrations with circuit breakers, and rate limiters — that timeline
    is not credible for one team.
  evidence: '- Week 1-2: Tasks 1-3 (core pipeline)

    '
  ask: Size each task independently. If the real core is Kafka-consumer + one channel (email), scope weeks 1-2 to that and add channels iteratively.
  severity: minor
  category: complexity
dropped_findings: []
---

## Summary

This plan has the bones of a solid notification service buried under two layers of speculative generality: a template engine that wants to be its own SaaS product (A/B testing, dependency graphs, two parsers, a preview API) and a multi-region topology that deserves its own design doc and gets a single week. The risk table is decoration — it restates mechanisms rather than naming failure conditions. Strip Task 2 down to Handlebars + S3 + locale folders, delete Task 6 entirely for now, and the remaining plan is deliverable in the stated timeline. As written, it is not.
