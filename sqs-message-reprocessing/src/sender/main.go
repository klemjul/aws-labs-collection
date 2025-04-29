package main

import (
	"context"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/google/uuid"
)

type Event struct {
	MessageCount int `json:"MessageCount"`
}

func handler(ctx context.Context, event Event) (string, error) {
	QueueURL := os.Getenv("QUEUE_URL")

	if event.MessageCount <= 0 {
		return "", fmt.Errorf("MessageCount must be greater than 0")
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to load AWS configuration: %v", err)
	}

	sqsClient := sqs.NewFromConfig(cfg)

	for i := 0; i < event.MessageCount; i++ {
		bodyId := uuid.New().String()

		res, err := sqsClient.SendMessage(ctx, &sqs.SendMessageInput{
			QueueUrl:    aws.String(QueueURL),
			MessageBody: aws.String(bodyId),
		})

		if err != nil {
			fmt.Printf("failed to send message to SQS: %v", err)
		} else {
			fmt.Printf("Message sent to SQS with ID: %s\n", *res.MessageId)
		}

	}
	return "Messages sent successfully", nil
}

func main() {
	lambda.Start(handler)
}
