output "users_table_arn" {
	value = aws_dynamodb_table.users.arn
}
output "users_table_name" {
	value = aws_dynamodb_table.users.name
}
output "todos_table_arn" {
	value = aws_dynamodb_table.todos.arn
}
output "todos_table_name" {
	value = aws_dynamodb_table.todos.name
}

