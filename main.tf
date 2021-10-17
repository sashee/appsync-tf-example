provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
			"dynamodb:Query",
			"dynamodb:Scan",
    ]
    resources = [
			module.database.users_table_arn,
			module.database.todos_table_arn,
    ]
  }
}

resource "aws_iam_role_policy" "appsync" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "appsync_test"
  schema              = file("schema.graphql")
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  user_pool_config {
    default_action = "DENY"
    user_pool_id   = module.cognito.user_pool_id
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

data "aws_iam_policy_document" "appsync_push_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_role" "appsync_logs" {
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
		"Effect": "Allow",
		"Principal": {
			"Service": "appsync.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
		}
	]
}
POLICY
}

resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync_logs.id
  policy = data.aws_iam_policy_document.appsync_push_logs.json
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

module "database" {
	source = "./modules/database"
}

resource "aws_appsync_datasource" "users" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "users"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = module.database.users_table_name
  }
}

resource "aws_appsync_datasource" "todos" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "todos"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = module.database.todos_table_name
  }
}

# resolvers

resource "aws_appsync_function" "Query_user_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_user_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"id": {"S": $util.toJson($ctx.args.id)}
	},
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "Query_user" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "user"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_user_1.function_id,
    ]
  }
}

resource "aws_appsync_function" "Query_allUsers_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_allUsers_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Scan",
	#if($ctx.args.count)
		,"limit": $util.toJson($ctx.args.count)
	#end
	#if($ctx.args.nextToken)
		,"nextToken": $util.toJson($ctx.args.nextToken)
	#end
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
{
	"items": $utils.toJson($ctx.result.items)
	#if($ctx.result.nextToken)
		,"nextToken": $util.toJson($ctx.result.nextToken)
	#end
}
EOF
}

resource "aws_appsync_resolver" "Query_allUsers" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "allUsers"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_allUsers_1.function_id,
    ]
  }
}

resource "aws_appsync_function" "Query_me_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_me_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"id": {"S": $util.toJson($ctx.identity.username)}
	},
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "Query_me" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "me"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_me_1.function_id,
    ]
  }
}

resource "aws_appsync_function" "Mutation_addTodo_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.todos.name
	name = "Mutation_addTodo_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "PutItem",
	"key" : {
		"userid": {"S": $util.toJson($ctx.arguments.userId)},
		"id": {"S": $util.toJson($util.autoId())}
	},
	"attributeValues": {
		"checked": {"BOOL": false},
		"created": {"S": $util.toJson($util.time.nowISO8601())},
		"name": {"S": $util.toJson($ctx.arguments.name)}
	}
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_function" "Mutation_addTodo_2" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.todos.name
	name = "Mutation_addTodo_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"userid": {"S": $util.toJson($ctx.prev.result.userid)},
		"id": {"S": $util.toJson($ctx.prev.result.id)}
	}
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "Mutation_addTodo" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Mutation"
  field       = "addTodo"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Mutation_addTodo_1.function_id,
      aws_appsync_function.Mutation_addTodo_2.function_id,
    ]
  }
}
resource "aws_appsync_function" "User_todos_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.todos.name
	name = "User_todos_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Query",
	"query" : {
		"expression": "userid = :userid",
			"expressionValues" : {
				":userid" : $util.dynamodb.toDynamoDBJson($ctx.source.id)
			}
	}
	#if($ctx.args.count)
			,"limit": $util.toJson($ctx.args.count)
	#end
	#if($ctx.args.nextToken)
			,"nextToken": $util.toJson($ctx.args.nextToken)
	#end
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
{
	"items": $utils.toJson($ctx.result.items)
	#if($ctx.result.nextToken)
		,"nextToken": $util.toJson($ctx.result.nextToken)
	#end
}
EOF
}

resource "aws_appsync_resolver" "User_todos_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "User"
  field       = "todos"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.User_todos_1.function_id,
    ]
  }
}

module "cognito" {
	source = "./modules/cognito"
}

# frontend cloudfront
module "frontend" {
	source = "./modules/frontend"

	cognito_user_pool_id = module.cognito.user_pool_id
	cognito_client_id = module.cognito.client_id
	backend_url = aws_appsync_graphql_api.appsync.uris["GRAPHQL"]
}

output "domain" {
  value = module.frontend.domain
}
