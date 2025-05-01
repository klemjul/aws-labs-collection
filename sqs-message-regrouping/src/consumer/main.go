package main

import (
	"context"
	"fmt"
	"os"
	"time"

	model "sqs-message-regrouping-model"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

var dynamoTable *dynamodb.Client
var dynamoTableName = os.Getenv("DYNAMODB_TABLE")
var dynamoTableOptions *model.TableOptions

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		panic(err)
	}
	dynamoTable = dynamodb.NewFromConfig(cfg)
	dynamoTableOptions = &model.TableOptions{
		DynamoDbClient: dynamoTable,
		TableName:      dynamoTableName,
	}
}

func HandleRequest(ctx context.Context, sqsEvent events.SQSEvent) {
	for _, record := range sqsEvent.Records {
		time.Sleep(1 * time.Second)
		err := processRecord(ctx, record, dynamoTableOptions)

		if err != nil {
			fmt.Printf("Error processing record %s: %v\n", record.MessageId, err)
		}
	}
}

func main() {
	lambda.Start(HandleRequest)
}

func processRecord(ctx context.Context, record events.SQSMessage, options *model.TableOptions) error {
	chatRoomId := record.Attributes["MessageGroupId"]
	sender := record.MessageAttributes["Sender"]
	messageId := record.MessageId
	messageBody := record.Body

	chatMessage := model.ChatMessage{
		Room:           chatRoomId,
		MessageId:      messageId,
		MessageContent: messageBody,
		Sender:         *sender.StringValue,
		Status:         "RECEIVED",
		CreatedAt:      time.Now().Format("2006-01-02T15:04:05.000Z07:00"),
	}

	return options.AddChatMessage(ctx, chatMessage)
}
