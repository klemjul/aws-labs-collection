package main

import (
	"context"
	"fmt"
	"log"
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

func HandleRequest(ctx context.Context, event SenderEvent) error {
	if event.MessageCountByRoom <= 0 || len(event.ChatRoomIds) == 0 {
		return fmt.Errorf("invalid input: MessageCountByRoom should be greater than 0 and ChatRoomIds should not be empty")
	}

	var wg sync.WaitGroup
	for _, chatRoom := range event.ChatRoomIds {
		wg.Add(1)
		go func(chatRoom string) {
			defer wg.Done()
			for i := 0; i < event.MessageCountByRoom; i++ {
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
					panic(err)
				}

				err = dynamoTableOptions.AddChatMessage(ctx, model.ChatMessage{
					Room:           chatRoom,
					MessageId:      *res.MessageId,
					MessageContent: messageBody,
					Sender:         sender,
					Status:         "SENT",
					CreatedAt:      time.Now().Format(time.RFC3339),
				})

				if err != nil {
					panic(err)
				}

				log.Printf("Sent '%s' to '%s'", *res.MessageId, chatRoom)
			}
		}(chatRoom)
	}
	wg.Wait()

	return nil
}

func main() {
	lambda.Start(HandleRequest)
}
