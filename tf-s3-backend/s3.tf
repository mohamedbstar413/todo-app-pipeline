provider "aws" {
  region = "us-east-1"
}
resource "aws_s3_bucket" "remote_backend_s3" {
  bucket =          "todo-s3-remote-backend-14120"
}