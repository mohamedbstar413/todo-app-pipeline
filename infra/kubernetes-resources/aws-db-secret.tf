resource "aws_secretsmanager_secret" "db_secret" {
  name =            "todo_db_secret"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = var.db_password
  })
}
