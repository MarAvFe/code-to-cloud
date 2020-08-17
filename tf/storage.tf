resource "aws_s3_bucket" "tfrmstate" {
  bucket        = "hello-pong-state-bucket"
  acl           = "private"
  force_destroy = true

  tags = {
    Name = "terraform remote state"
  }
}

resource "aws_s3_bucket_object" "rmstate_folder" {
  bucket = "${aws_s3_bucket.tfrmstate.id}"
  key = "eks/"
}