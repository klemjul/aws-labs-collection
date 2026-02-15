# DynamoDB Stream to OpenSearch

## Goal

Real-time data sync pipeline: DynamoDB changes automatically indexed to OpenSearch via DynamoDB Streams. Combines fast key-value lookups (DynamoDB) with full-text search (OpenSearch).

## Architecture

```mermaid
graph LR
    CSV[CSV File] --> S3[S3 Bucket]
    S3 --> L1[Lambda<br/>CSV Ingestion]
    L1 --> DDB[(DynamoDB<br/>Table)]
    DDB --> Stream[DynamoDB<br/>Stream]
    Stream --> L2[Lambda<br/>Stream Processor]
    L2 --> OS[(OpenSearch<br/>Domain)]

    style DDB fill:#527FFF
    style OS fill:#527FFF
    style Stream fill:#D97706
    style L1 fill:#D97706
    style L2 fill:#D97706
    style S3 fill:#569A31
```

## Improvements

More infos: https://github.com/klemjul/aws-labs-collection/pull/7

- [ ] go: Improve error handling in the stream code
- [ ] tf: Better IAM restrictions
- [ ] tf: OpenSearch Advanced IAM security
- [ ] tf: Improve build null_resource trigger condition
