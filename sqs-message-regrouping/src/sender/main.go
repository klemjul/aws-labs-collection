package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"
	"time"

	model "sqs-message-regrouping-model"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/google/uuid"
)

var sqsClient *sqs.Client
var queueURL = os.Getenv("QUEUE_URL")
var dynamoTable *dynamodb.Client
var dynamoTableName = os.Getenv("DYNAMODB_TABLE")
var dynamoTableOptions *model.TableOptions

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		panic(err)
	}
	sqsClient = sqs.NewFromConfig(cfg)
	dynamoTable = dynamodb.NewFromConfig(cfg)
	dynamoTableOptions = &model.TableOptions{
		DynamoDbClient: dynamoTable,
		TableName:      dynamoTableName,
	}
}

type SenderEvent struct {
	MessageCountByRoom int      `json:"MessageCountByRoom"`
	ChatRoomIds        []string `json:"ChatRoomIds"`
}

func HandleRequest(ctx context.Context, event SenderEvent) (map[string][]string, error) {
	if event.MessageCountByRoom <= 0 || len(event.ChatRoomIds) == 0 {
		return nil, fmt.Errorf("invalid input: MessageCountByRoom must be greater than 0 and ChatRoomIds must not be empty")
	}

	var wg sync.WaitGroup
	resultsChan := make(chan map[string][]string, len(event.ChatRoomIds))
	errorChannel := make(chan error, len(event.ChatRoomIds))

	for _, chatRoom := range event.ChatRoomIds {
		wg.Add(1)
		go func(chatRoom string) {
			defer wg.Done()
			sentMessageIds, err := sendMessagesToChatRoom(ctx, chatRoom, event.MessageCountByRoom)
			errorChannel <- err
			resultsChan <- sentMessageIds
		}(chatRoom)
	}

	wg.Wait()
	close(resultsChan)
	close(errorChannel)

	fResults := collectResults(resultsChan)
	fErrors := collectErrors(errorChannel)

	return fResults, errors.Join(fErrors...)
}

func main() {
	lambda.Start(HandleRequest)
}

func collectErrors(errorChannel <-chan error) []error {
	var errors []error
	for err := range errorChannel {
		if err != nil {
			errors = append(errors, err)
		}
	}
	return errors
}

func collectResults(resultsChan <-chan map[string][]string) map[string][]string {
	finalResults := make(map[string][]string)
	for result := range resultsChan {
		for chatRoom, messageIds := range result {
			finalResults[chatRoom] = append(finalResults[chatRoom], messageIds...)
		}
	}
	return finalResults
}

func sendMessagesToChatRoom(ctx context.Context, chatRoom string, messageCount int) (map[string][]string, error) {
	sentMessageIds := make(map[string][]string)
	for i := 0; i < messageCount; i++ {
		messageBody := fmt.Sprintf("%d: %s", i, uuid.New().String())
		sender := "BOT"
		if i%2 == 0 {
			sender = "USER"
		}

		res, err := sqsClient.SendMessage(context.TODO(), &sqs.SendMessageInput{
			QueueUrl:       aws.String(queueURL),
			MessageBody:    aws.String(messageBody),
			MessageGroupId: aws.String(chatRoom),
			MessageAttributes: map[string]types.MessageAttributeValue{
				"Sender": {
					DataType:    aws.String("String"),
					StringValue: aws.String(sender),
				},
			},
		})

		if err != nil {
			return nil, fmt.Errorf("failed to send message: %w", err)
		}

		err = dynamoTableOptions.AddChatMessage(ctx, model.ChatMessage{
			Room:           chatRoom,
			MessageId:      *res.MessageId,
			MessageContent: messageBody,
			Sender:         sender,
			Status:         "SENT",
			CreatedAt:      time.Now().Format("2006-01-02T15:04:05.000Z07:00"),
		})

		if err != nil {
			return nil, fmt.Errorf("failed to add chat message to DynamoDB: %w", err)
		}

		sentMessageIds[chatRoom] = append(sentMessageIds[chatRoom], *res.MessageId)
	}
	return sentMessageIds, nil
}
