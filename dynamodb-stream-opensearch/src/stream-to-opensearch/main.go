package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"regexp"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/opensearch-project/opensearch-go/v4"
	"github.com/opensearch-project/opensearch-go/v4/opensearchapi"
	"github.com/opensearch-project/opensearch-go/v4/opensearchutil"
	requestsigner "github.com/opensearch-project/opensearch-go/v4/signer/awsv2"
)

var (
	opensearchEndpoint string
	opensearchIndex    string
	osClient           *opensearchapi.Client
)

func init() {
	opensearchEndpoint = os.Getenv("OPENSEARCH_ENDPOINT")
	opensearchIndex = os.Getenv("OPENSEARCH_INDEX")
}

// Document represents the structure to index in OpenSearch
type Document struct {
	PK        string                 `json:"pk"`
	SK        string                 `json:"sk"`
	Data      map[string]interface{} `json:"data"`
	Timestamp string                 `json:"timestamp"`
}

func initClient(ctx context.Context) error {
	if osClient != nil {
		return nil
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("failed to load AWS config: %w", err)
	}

	signer, err := requestsigner.NewSignerWithService(cfg, "es") // "es" for OpenSearch Service
	if err != nil {
		return fmt.Errorf("failed to create request signer: %w", err)
	}

	osClient, err = opensearchapi.NewClient(
		opensearchapi.Config{
			Client: opensearch.Config{
				Addresses: []string{fmt.Sprintf("https://%s", opensearchEndpoint)},
				Signer:    signer,
			},
		},
	)
	if err != nil {
		return fmt.Errorf("failed to create opensearch client: %w", err)
	}

	return nil
}

// normalizeDocID removes or replaces forbidden characters in OpenSearch document IDs
func normalizeDocID(id string) string {
	id = regexp.MustCompile(`[/\\]`).ReplaceAllString(id, "-")
	id = regexp.MustCompile(`\s+`).ReplaceAllString(id, "-")
	id = regexp.MustCompile(`\x00`).ReplaceAllString(id, "")
	id = regexp.MustCompile(`-+`).ReplaceAllString(id, "-")
	id = regexp.MustCompile(`^-|-$`).ReplaceAllString(id, "")
	return id
}

func handler(ctx context.Context, event events.DynamoDBEvent) error {
	if err := initClient(ctx); err != nil {
		return err
	}

	for _, record := range event.Records {
		log.Printf("Processing record: %s, Event type: %s", record.EventID, record.EventName)

		switch record.EventName {
		case "INSERT", "MODIFY":
			if err := indexDocument(ctx, record); err != nil {
				log.Printf("Error indexing document: %v", err)
				return err
			}
		case "REMOVE":
			if err := deleteDocument(ctx, record); err != nil {
				log.Printf("Error deleting document: %v", err)
				return err
			}
		}
	}

	log.Printf("Successfully processed %d records", len(event.Records))
	return nil
}

func indexDocument(ctx context.Context, record events.DynamoDBEventRecord) error {
	// Convert DynamoDB attribute values to a map
	data := make(map[string]interface{})
	for key, value := range record.Change.NewImage {
		data[key] = attributeValueToInterface(value)
	}

	pk := getStringValue(record.Change.NewImage["pk"])
	sk := getStringValue(record.Change.NewImage["sk"])

	doc := Document{
		PK:        pk,
		SK:        sk,
		Data:      data,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	// Create document ID from pk and sk
	docID := normalizeDocID(fmt.Sprintf("%s#%s", pk, sk))

	// Index the document using the OpenSearch client
	_, err := osClient.Index(
		ctx,
		opensearchapi.IndexReq{
			Index:      opensearchIndex,
			DocumentID: docID,
			Body:       opensearchutil.NewJSONReader(&doc),
		},
	)
	if err != nil {
		return fmt.Errorf("failed to index document: %w", err)
	}

	log.Printf("Indexed document %s successfully", docID)
	return nil
}

func deleteDocument(ctx context.Context, record events.DynamoDBEventRecord) error {
	pk := getStringValue(record.Change.OldImage["pk"])
	sk := getStringValue(record.Change.OldImage["sk"])
	docID := normalizeDocID(fmt.Sprintf("%s#%s", pk, sk))

	// Delete the document using the OpenSearch client
	_, err := osClient.Document.Delete(
		ctx,
		opensearchapi.DocumentDeleteReq{
			Index:      opensearchIndex,
			DocumentID: docID,
		},
	)
	if err != nil {
		// Ignore 404 errors (document not found)
		var opensearchErr *opensearch.StructError
		if errors.As(err, &opensearchErr) && opensearchErr.Err.Type == "index_not_found_exception" {
			log.Printf("Document %s not found, skipping delete", docID)
			return nil
		}
		return fmt.Errorf("failed to delete document: %w", err)
	}

	log.Printf("Deleted document %s successfully", docID)
	return nil
}

func attributeValueToInterface(av events.DynamoDBAttributeValue) interface{} {
	switch av.DataType() {
	case events.DataTypeString:
		return av.String()
	case events.DataTypeNumber:
		return av.Number()
	case events.DataTypeBoolean:
		return av.Boolean()
	case events.DataTypeList:
		list := av.List()
		result := make([]interface{}, len(list))
		for i, item := range list {
			result[i] = attributeValueToInterface(item)
		}
		return result
	case events.DataTypeMap:
		m := av.Map()
		result := make(map[string]interface{})
		for k, v := range m {
			result[k] = attributeValueToInterface(v)
		}
		return result
	default:
		return nil
	}
}

func getStringValue(av events.DynamoDBAttributeValue) string {
	if av.DataType() == events.DataTypeString {
		return av.String()
	}
	return ""
}

func main() {
	lambda.Start(handler)
}
