package main

import (
	"context"
	"os"
	"reflect"
	"sort"

	model "sqs-message-regrouping-model"

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

type SenderEvent struct {
	ChatRoomId string `json:"ChatRoomId"`
}

type TestResult struct {
	SentMessagesIds        []string `json:"SentMessagesIds"`
	ReceivedMessagesIds    []string `json:"ReceivedMessagesIds"`
	AreSentAndReceivedSame bool     `json:"AreSentAndReceivedSame"`
}

func HandleRequest(ctx context.Context, event SenderEvent) (*TestResult, error) {
	roomMessages, err := dynamoTableOptions.QueryByRoom(ctx, event.ChatRoomId)
	if err != nil {
		return nil, err
	}

	var sentMessagesIds []string
	var receivedMessagesIds []string

	for _, message := range roomMessages {
		if message.Status == "SENT" {
			sentMessagesIds = append(sentMessagesIds, message.MessageId)
		}
		if message.Status == "RECEIVED" {
			receivedMessagesIds = append(receivedMessagesIds, message.MessageId)
		}
	}

	sort.Slice(roomMessages, func(i, j int) bool {
		return roomMessages[i].CreatedAt < roomMessages[j].CreatedAt
	})

	isSameBetweenSentAndReceived := reflect.DeepEqual(sentMessagesIds, receivedMessagesIds)
	return &TestResult{
		SentMessagesIds:        sentMessagesIds,
		ReceivedMessagesIds:    receivedMessagesIds,
		AreSentAndReceivedSame: isSameBetweenSentAndReceived,
	}, nil

}

func main() {
	lambda.Start(HandleRequest)
}
