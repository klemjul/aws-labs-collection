package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

func main() {
	lambda.Start(handleMessage)
}

func handleMessage(ctx context.Context, sqsEvent events.SQSEvent) (events.SQSEventResponse, error) {
	mode := os.Getenv("MODE")
	var batchItemFailures = make([]events.SQSBatchItemFailure, 0)

	printMessageIDs(sqsEvent, mode)
	// Simulate processing delay
	time.Sleep(2 * time.Second)

	if mode == "THROW" {
		// Simulate hard failure by throwing an error
		var errorMessages []string
		for _, record := range sqsEvent.Records {
			errorMessages = append(errorMessages, record.MessageId)
		}
		return events.SQSEventResponse{}, fmt.Errorf("DEBUG (THROWING) %v", errorMessages)
	}
	// https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-errorhandling.html#services-sqs-batchfailurereporting
	if mode == "PARTIAL_FAILURE" {
		// Simulate partial failure by failing one message of two
		for i, record := range sqsEvent.Records {
			if i%2 != 0 {
				batchItemFailures = append(batchItemFailures, events.SQSBatchItemFailure{
					ItemIdentifier: record.MessageId,
				})
			}
		}
	}
	if mode == "DROP_AFTER_3_ATTEMPTS" {
		// Delete the message(s) from the queue after 3 attempts by marking as successfully processed
		for _, record := range sqsEvent.Records {
			if record.Attributes["ApproximateReceiveCount"] == "3" {
				log.Printf("DEBUG (DROPPED after 3 attempts) %s", record.MessageId)
				continue
			}
			batchItemFailures = append(batchItemFailures, events.SQSBatchItemFailure{
				ItemIdentifier: record.MessageId,
			})
		}
	}
	if mode == "DLQ_AFTER_2_ATTEMPTS" {
		// Fail all messages, sqs will move them to the DLQ after 2 attempts
		for _, record := range sqsEvent.Records {
			batchItemFailures = append(batchItemFailures, events.SQSBatchItemFailure{
				ItemIdentifier: record.MessageId,
			})
		}
	}

	if mode == "IMMEDIATE_REPROCESSING" {
		// Simulate immediate reprocessing by failing all messages and expire visibility timeout
		queueURL := os.Getenv("QUEUE_URL")
		cfg, err := config.LoadDefaultConfig(ctx)
		if err != nil {
			log.Printf("unable to load SDK config, %v", err)
		}
		sqsClient := sqs.NewFromConfig(cfg)

		for _, record := range sqsEvent.Records {
			batchItemFailures = append(batchItemFailures, events.SQSBatchItemFailure{
				ItemIdentifier: record.MessageId,
			})
			_, err = sqsClient.ChangeMessageVisibility(ctx, &sqs.ChangeMessageVisibilityInput{
				QueueUrl:          aws.String(queueURL),
				ReceiptHandle:     &record.ReceiptHandle,
				VisibilityTimeout: 0,
			})
			if err != nil {
				log.Printf("unable to change message visibility, %v", err)
			}
		}
	}

	printBatchItemFailures(batchItemFailures)

	return events.SQSEventResponse{
		BatchItemFailures: batchItemFailures,
	}, nil
}

func printMessageIDs(sqsEvent events.SQSEvent, mode string) {
	var messageIDs []string
	for _, record := range sqsEvent.Records {
		messageIDs = append(messageIDs, record.MessageId)
	}
	log.Printf("DEBUG (RECEIVED) %s %v", mode, messageIDs)
}

func printBatchItemFailures(batchItemFailures []events.SQSBatchItemFailure) {
	var failedItems []string
	for _, failure := range batchItemFailures {
		failedItems = append(failedItems, failure.ItemIdentifier)
	}
	log.Printf("DEBUG (FAILED) %v", failedItems)
}
