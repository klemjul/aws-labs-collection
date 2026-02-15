package main

import (
	"context"
	"encoding/csv"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var (
	s3Client       *s3.Client
	dynamodbClient *dynamodb.Client
	tableName      string
)

const separator rune = ';'
const pkColumn = "pk"
const skColumn = "sk"

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("Unable to load SDK config: %v", err)
	}

	s3Client = s3.NewFromConfig(cfg)
	dynamodbClient = dynamodb.NewFromConfig(cfg)
	tableName = os.Getenv("TABLE_NAME")

	if tableName == "" {
		log.Fatal("TABLE_NAME environment variable is required")
	}
}

func handler(ctx context.Context, s3Event events.S3Event) error {
	for _, record := range s3Event.Records {
		bucket := record.S3.Bucket.Name
		key := record.S3.Object.Key

		log.Printf("Processing file: s3://%s/%s", bucket, key)

		// Get the CSV file from S3
		obj, err := s3Client.GetObject(ctx, &s3.GetObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String(key),
		})
		if err != nil {
			log.Printf("Failed to get object: %v", err)
			return fmt.Errorf("failed to get object from S3: %w", err)
		}
		defer obj.Body.Close()

		// Parse CSV
		reader := csv.NewReader(obj.Body)
		reader.Comma = separator
		headers, err := reader.Read()
		if err != nil {
			log.Printf("Failed to read CSV header: %v", err)
			return fmt.Errorf("failed to read CSV header: %w", err)
		}
		log.Printf("CSV Headers: %v", headers)

		// Validate required columnss
		pkExists := false
		skExists := false
		for _, header := range headers {
			if header == pkColumn {
				pkExists = true
			}
			if header == skColumn {
				skExists = true
			}
		}
		if !pkExists || !skExists {
			return fmt.Errorf("CSV must contain '%s' and '%s' columns", pkColumn, skColumn)
		}

		// Process rows and insert into DynamoDB with batch writes
		rowNum := 0
		batch := make([]types.WriteRequest, 0, 25)
		batchSize := 25

		flushBatch := func() error {
			if len(batch) == 0 {
				return nil
			}

			_, err := dynamodbClient.BatchWriteItem(ctx, &dynamodb.BatchWriteItemInput{
				RequestItems: map[string][]types.WriteRequest{
					tableName: batch,
				},
			})
			if err != nil {
				return fmt.Errorf("failed to batch write items: %w", err)
			}
			batch = make([]types.WriteRequest, 0, batchSize)
			return nil
		}

		for {
			record, err := reader.Read()
			if err != nil {
				if err.Error() == "EOF" {
					break
				}
				log.Printf("Error reading CSV row %d: %v", rowNum, err)
				continue
			}

			// Convert CSV row to map
			item := make(map[string]interface{})
			for i, header := range headers {
				if i < len(record) {
					item[header] = record[i]
				}
			}

			// Marshal to DynamoDB format
			av, err := attributevalue.MarshalMap(item)
			if err != nil {
				log.Printf("Failed to marshal item at row %d: %v", rowNum, err)
				continue
			}

			// Add to batch
			batch = append(batch, types.WriteRequest{
				PutRequest: &types.PutRequest{
					Item: av,
				},
			})

			// Flush batch when full
			if len(batch) >= batchSize {
				if err := flushBatch(); err != nil {
					log.Printf("Error flushing batch: %v", err)
					return err
				}
			}

			rowNum++
		}

		// Flush remaining items
		if err := flushBatch(); err != nil {
			log.Printf("Error flushing final batch: %v", err)
			return err
		}

		log.Printf("Successfully processed %d rows from %s", rowNum, key)
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
