resource "aws_s3_bucket" "example" {
  bucket = "devils-council-example-${var.environment}"

  tags = {
    Project = "devils-council"
    Owner   = "platform"
  }
}

resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id

  versioning_configuration {
    status = "Enabled"
  }
}
