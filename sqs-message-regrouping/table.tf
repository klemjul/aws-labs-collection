resource "aws_dynamodb_table" "table" {
  name         = "${var.resource_prefix}-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "MessageId"
  range_key    = "Status"

  attribute {
    name = "MessageId"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  attribute {
    name = "Room"
    type = "S"
  }

  global_secondary_index {
    name            = "RoomIndex"
    hash_key        = "Room"
    projection_type = "ALL"
  }
}
