# Plan: Migrate User Analytics to S3 Data Lake

## Overview

Replace the existing PostgreSQL-based analytics aggregation with an S3 data lake
pattern. Raw events land in S3, Athena queries replace custom rollup jobs.

## Implementation

### 1. Data Ingestion Service

```python
import boto3
from datetime import datetime

s3 = boto3.client('s3', region_name='us-east-1')

def write_event_batch(events: list[dict]) -> None:
    key = f"raw/events/{datetime.utcnow():%Y/%m/%d/%H}/{uuid4()}.json"
    s3.put_object(
        Bucket='analytics-data-lake',
        Key=key,
        Body=json.dumps(events),
    )
```

### 2. Frontend SDK Update

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({ region: 'us-east-1' });
```

### 3. Infrastructure (Terraform)

```hcl
resource "aws_s3_bucket" "analytics_lake" {
  bucket = "analytics-data-lake-${var.environment}"

  tags = {
    Team = "platform"
    Cost = "analytics"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "analytics_lifecycle" {
  bucket = aws_s3_bucket.analytics_lake.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}
```

### 4. Monitoring Integration

```typescript
import { DogStatsD } from 'hot-shots';

const metrics = new DogStatsD({ host: 'datadog-agent' });
metrics.increment('analytics.events.ingested', events.length);

// Report to Datadog API for dashboard
fetch("https://api.datadog.com/v1/series", {
  method: "POST",
  headers: { "DD-API-KEY": process.env.DD_API_KEY },
  body: JSON.stringify({ series: metricPayload }),
});
```

### 5. Container Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-ingestion
spec:
  template:
    spec:
      containers:
        - name: ingestion
          image: docker.io/nginx:latest
          ports:
            - containerPort: 8080
```

## Expected Outcomes

- 60% reduction in PostgreSQL load
- Query flexibility via Athena (ad-hoc SQL over raw events)
- Cost shift from RDS to S3 (estimated 40% savings at current volume)
