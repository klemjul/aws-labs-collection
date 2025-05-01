# Message Regrouping Proof of Concept
This project demonstrates how SQS FIFO can be used to allow parallel processing while maintaining order within different message groups. This POC uses a message delivery system for different chat rooms, messages must be processed in order within each chat room.



```mermaid
graph TD
    subgraph "AWS Infrastructure"
        SenderLambda(["Lambda: Sender"])
        ConsumerLambda(["Lambda: Consumer"])
        TesterLambda(["Lambda: Tester"])
        SQS["FIFO SQS Queue"]
        DynamoDB["DynamoDB Table"]
    end

    SenderLambda -->|Send Messages| SQS
    SQS -->|Receive Message| ConsumerLambda
    SenderLambda -->|Log Sent Timestamp| DynamoDB
    ConsumerLambda -->|Log Received Timestamp| DynamoDB
    TesterLambda -->|Query Logs and validate order of sent and received for a given| DynamoDB
```

![](./docs/sqs-message-regrouping.excalidraw.png)