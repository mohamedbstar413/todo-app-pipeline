resource "aws_secretsmanager_secret" "db_secret" {
  name =            "todo_db_secret_10"
  recovery_window_in_days = 0 #force to delete instantly
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = var.db_password
  })
}