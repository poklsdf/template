#------------------
# Test Bucket
#------------------
resource "aws_s3_bucket" "bucket" {
  bucket = "jlao-lifecycle-test"
  acl    = "private"
  versioning {
    enabled = false
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket-lifecycle-config" {
  bucket = "jlao-lifecycle-test"

  rule {
    id = "intelligent-tiering"
    #abort_incomplete_multipart_upload {
    #  days_after_initiation = 0
    #}
    status = "Enabled"
    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}