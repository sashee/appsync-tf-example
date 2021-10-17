resource "random_id" "id" {
  byte_length = 8
}

resource "aws_dynamodb_table" "users" {
  name           = "Users-${random_id.id.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "todos" {
  name           = "Todos-${random_id.id.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userid"
	range_key = "id"

  attribute {
    name = "userid"
    type = "S"
  }

  attribute {
    name = "id"
    type = "S"
  }
}

## sample data

resource "aws_dynamodb_table_item" "user1" {
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key
  range_key   = aws_dynamodb_table.users.range_key

  item = <<ITEM
{
  "id": {"S": "user1@example.com"},
	"name": {"S": "user 1"}
}
ITEM
}

resource "aws_dynamodb_table_item" "user2" {
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key
  range_key   = aws_dynamodb_table.users.range_key

  item = <<ITEM
{
  "id": {"S": "user2@example.com"},
	"name": {"S": "user 2"}
}
ITEM
}

resource "aws_dynamodb_table_item" "todo1" {
  table_name = aws_dynamodb_table.todos.name
  hash_key   = aws_dynamodb_table.todos.hash_key
  range_key   = aws_dynamodb_table.todos.range_key

  item = <<ITEM
{
  "userid": {"S": "user1@example.com"},
  "id": {"S": "todo-1-id"},
	"name": {"S": "todo 1"},
	"checked": {"BOOL": true},
	"created": {"S": "2021-10-15T08:15:09.995Z"}
}
ITEM
}

resource "aws_dynamodb_table_item" "todo2" {
  table_name = aws_dynamodb_table.todos.name
  hash_key   = aws_dynamodb_table.todos.hash_key
  range_key   = aws_dynamodb_table.todos.range_key

  item = <<ITEM
{
  "userid": {"S": "user1@example.com"},
  "id": {"S": "todo-2-id"},
	"name": {"S": "todo 2"},
	"checked": {"BOOL": false},
	"created": {"S": "2021-10-15T08:15:31.117Z"}
}
ITEM
}

resource "aws_dynamodb_table_item" "todo3" {
  table_name = aws_dynamodb_table.todos.name
  hash_key   = aws_dynamodb_table.todos.hash_key
  range_key   = aws_dynamodb_table.todos.range_key

  item = <<ITEM
{
  "userid": {"S": "user2@example.com"},
  "id": {"S": "todo-3-id"},
	"name": {"S": "todo 3"},
	"checked": {"BOOL": false},
	"created": {"S": "2021-10-15T08:15:31.117Z"}
}
ITEM
}
