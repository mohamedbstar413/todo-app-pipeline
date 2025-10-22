resource "aws_s3_bucket" "todo_front_nginx_config_s3" {
  bucket =              "todo-front-nginx-config-s3-unique-14120"
  force_destroy =       true
}

resource "aws_s3_bucket_public_access_block" "todo_s3_access_block" {
  bucket =              aws_s3_bucket.todo_front_nginx_config_s3.id

  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "null_resource" "upload_nginx_conf_file" {
  depends_on = [ aws_s3_bucket.todo_front_nginx_config_s3 ]

  provisioner "local-exec" {
    command = <<EOT
      aws s3 cp nginx.conf s3://${aws_s3_bucket.todo_front_nginx_config_s3.bucket}/
    EOT
  }
}


output "config_s3_url" {
  value = aws_s3_bucket.todo_front_nginx_config_s3.bucket_domain_name
}
