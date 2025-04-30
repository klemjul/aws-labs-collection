package model

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/expression"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go/aws"
)

type ChatMessage struct {
	Room           string `json:"ChatRoom"`
	MessageId      string `json:"MessageId"`
	MessageContent string `json:"MessageContent"`
	Sender         string `json:"Sender"`
	Status         string `json:"Status"` // Status can be "SENT" or "RECEIVED"
	CreatedAt      string `json:"CreatedAt"`
}

func (msg ChatMessage) GetKey() map[string]types.AttributeValue {
	title, err := attributevalue.Marshal(msg.Room)
	if err != nil {
		panic(err)
	}
	messageId, err := attributevalue.Marshal(msg.MessageId)
	if err != nil {
		panic(err)
	}
	return map[string]types.AttributeValue{"": title, "MessageId": messageId}
}

func (msg ChatMessage) String() string {
	return fmt.Sprintf("[%v] %v: %v", msg.Room, msg.Sender, msg.MessageContent)
}

type TableOptions struct {
	DynamoDbClient *dynamodb.Client
	TableName      string
}

func (tableOpts TableOptions) AddChatMessage(ctx context.Context, message ChatMessage) error {
	item, err := attributevalue.MarshalMap(message)
	if err != nil {
		panic(err)
	}
	_, err = tableOpts.DynamoDbClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableOpts.TableName), Item: item,
	})
	return err
}

func (tableOpts TableOptions) Query(ctx context.Context, room string) ([]ChatMessage, error) {
	var err error
	var response *dynamodb.QueryOutput
	var messages []ChatMessage
	keyEx := expression.Key("room").Equal(expression.Value(room))
	expr, err := expression.NewBuilder().WithKeyCondition(keyEx).Build()
	if err != nil {
		return messages, err
	}
	queryPaginator := dynamodb.NewQueryPaginator(tableOpts.DynamoDbClient, &dynamodb.QueryInput{
		TableName:                 aws.String(tableOpts.TableName),
		ExpressionAttributeNames:  expr.Names(),
		ExpressionAttributeValues: expr.Values(),
		KeyConditionExpression:    expr.KeyCondition(),
	})
	for queryPaginator.HasMorePages() {
		response, err = queryPaginator.NextPage(ctx)
		if err != nil {
			return messages, err
		}
		var messagesPage []ChatMessage
		err = attributevalue.UnmarshalListOfMaps(response.Items, &messagesPage)
		if err != nil {
			return messages, err
		}
		messages = append(messages, messagesPage...)
	}
	return messages, err
}
