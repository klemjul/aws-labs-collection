resource "aws_dynamodb_table" "table" {
  name         = "${var.resource_prefix}-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Room"
  range_key    = "MessageId"

  attribute {
    name = "Room"
    type = "S"
  }

  attribute {
    name = "MessageId"
    type = "S"
  }
}
