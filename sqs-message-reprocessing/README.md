# Message Reprocessing Proof of Concept

This project demonstrates message reprocessing in a queue with various failure scenarios.



```mermaid
graph LR
    A[consumer] -->|Processes Messages| B[queue]
    C[sender] -->|Sends Messages| B
    B -->|Delivers to consumer| A
    B -->|Optional Failures| D[dlq]
```

Sender lambda can be invoked directly from the AWS Console or using AWS CLI.

## Differents Demos

Demo mode can be configured using [variables.tf](./variables.tf) `demo_mode`

### NONE

![](./docs/NONE.png)

### THROW

![](./docs/THROW.png)

### PARTIAL_FAILURE

![](./docs/PARTIAL_FAILURE.png)

### DROP_AFTER_3_ATTEMPTS

![](./docs/DROP_AFTER_3_ATTEMPTS.png)

### DLQ_AFTER_2_ATTEMPTS

![](./docs/DLQ_AFTER_2_ATTEMPTS.png)

### IMMEDIATE_REPROCESSING
![](./docs/IMMEDIATE_REPROCESSING.png)