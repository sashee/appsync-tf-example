resource "random_id" "id" {
  byte_length = 8
}

data "archive_file" "auto_confirm_lambda_code" {
  type        = "zip"
  output_path = "/tmp/${random_id.id.hex}-auto_confirm_lambda.zip"
  source {
    content  = <<EOF
module.exports.handler = async (event) => {
	event.response.autoConfirmUser = true;
	return event;
};
EOF
    filename = "index.js"
  }
}

resource "aws_lambda_function" "auto_confirm" {
  function_name = "auto-confirm-${random_id.id.hex}-function"

  filename         = data.archive_file.auto_confirm_lambda_code.output_path
  source_code_hash = data.archive_file.auto_confirm_lambda_code.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs14.x"
  role    = aws_iam_role.auto_confirm.arn
}

resource "aws_iam_role" "auto_confirm" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
	{
	  "Action": "sts:AssumeRole",
	  "Principal": {
			"Service": "lambda.amazonaws.com"
	  },
	  "Effect": "Allow"
	}
  ]
}
EOF
}

data "archive_file" "post_confirmation_lambda_code" {
  type        = "zip"
  output_path = "/tmp/${random_id.id.hex}-post_confirmation_lambda.zip"
  source {
    content  = <<EOF
const AWS = require("aws-sdk");

module.exports.handler = async (event) => {
	const {userName, userPoolId} = event;
	const cognito = new AWS.CognitoIdentityServiceProvider();

	await cognito.adminAddUserToGroup({
		UserPoolId: userPoolId,
		Username: userName,
		GroupName: userName.startsWith("admin") ? process.env.adminUserGroup : process.env.userUserGroup,
	}).promise();

	return event;
};
EOF
    filename = "index.js"
  }
}

resource "aws_lambda_function" "post_confirmation" {
  function_name = "post-confirmation-${random_id.id.hex}-function"

  filename         = data.archive_file.post_confirmation_lambda_code.output_path
  source_code_hash = data.archive_file.post_confirmation_lambda_code.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs14.x"
  role    = aws_iam_role.post_confirmation.arn
	environment {
		variables = {
			adminUserGroup = "admin"
			userUserGroup = "user"
		}
	}
}

resource "aws_cloudwatch_log_group" "post_confirmation" {
  name              = "/aws/lambda/${aws_lambda_function.post_confirmation.function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "post_confirmation" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  statement {
    actions = [
			"cognito-idp:AdminAddUserToGroup"
    ]
    resources = [
      aws_cognito_user_pool.pool.arn
    ]
  }
}

resource "aws_iam_role" "post_confirmation" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
	{
	  "Action": "sts:AssumeRole",
	  "Principal": {
			"Service": "lambda.amazonaws.com"
	  },
	  "Effect": "Allow"
	}
  ]
}
EOF
}

resource "aws_iam_role_policy" "post_confirmation" {
  role   = aws_iam_role.post_confirmation.id
  policy = data.aws_iam_policy_document.post_confirmation.json
}

resource "aws_lambda_permission" "auto_confirm" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_confirm.arn
  principal     = "cognito-idp.amazonaws.com"

  source_arn = aws_cognito_user_pool.pool.arn
}

resource "aws_lambda_permission" "post_confirmation" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.arn
  principal     = "cognito-idp.amazonaws.com"

  source_arn = aws_cognito_user_pool.pool.arn
}

resource "aws_cognito_user_pool" "pool" {
  name = "test-${random_id.id.hex}"
  lambda_config {
    pre_sign_up = aws_lambda_function.auto_confirm.arn
		post_confirmation = aws_lambda_function.post_confirmation.arn
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "client"

  user_pool_id                         = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "user" {
  name         = "user"
  user_pool_id = aws_cognito_user_pool.pool.id
}
