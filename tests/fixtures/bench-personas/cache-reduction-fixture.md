# Plan: Add metrics dashboard for chart rendering latency

## Context

The `anaconda-platform-chart` Helm chart ships a Grafana instance that
surfaces basic pod-level metrics but no per-chart rendering latency.
Customers hit slow renders on Notebooks view and file a support ticket
roughly twice per month. We have Datadog wired for SaaS; self-hosted
customers run Prometheus + Grafana shipped with the chart.

## Goal

Add a Grafana dashboard that shows p50/p95/p99 chart-rendering latency
broken down by chart type and by tenant.

## Approach

1. Pin `prometheus-client==0.20.0` exactly in `requirements.txt` — we
   bundle deps for the air-gapped customer registry.
2. Surface a new Helm value in `values.yaml` to opt into tenant tagging.
3. Ship a Grafana dashboard + HPA + dedicated storage class.

### Chart metadata (Chart.yaml)

```yaml
apiVersion: v2
name: platform-metrics
version: 1.4.0
type: application
description: Chart rendering latency dashboard subchart
```

### Autoscaler (templates/plot-hpa.yaml)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: plot-service
spec:
  minReplicas: 2
  maxReplicas: 12
  scaleTargetRef:
    kind: Deployment
    name: plot-service
```

### Storage overlay (templates/metrics-pvc.yaml)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plot-metrics
spec:
  storageClassName: gp3-metrics
  resources:
    requests:
      storage: 20Gi
```

## Rollout

- Merge to main; CI builds a new chart version.
- Deploy to SaaS staging; confirm dashboard loads with synthetic load.
- Backport to the last two supported chart versions for self-hosted.
- Add runbook entry for "dashboard empty" → check ServiceMonitor labels.

## Risks

- **Cardinality**: `tenant_id` as a Prometheus label explodes series
  count on SaaS where we have many active tenants. Mitigation: hash
  tenant_id to a 10-bit bucket so cardinality caps at ~1k.
- **Self-hosted scraper**: single-tenant customers do not need tenant
  labeling. Default off; enable explicitly for SaaS.
- **Registry mirror**: the pinned `requirements.txt` entry must be
  mirrored in the customer registry for air-gap installs before cut.

## Success criteria

- Dashboard p50/p95/p99 latency populated within 24h of deploy.
- No Prometheus cardinality alerts within 7 days.
- At least one SRE has used the dashboard in an incident investigation.
- Support tickets tagged `slow-chart-rendering` decrease month-over-month
  for two consecutive months.
