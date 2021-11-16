output "bucket" {
	value = aws_s3_bucket.web_bucket # exposing entire bucket object
}

# output of this is an object with properties like "id", "name", etc.
output "instance_profile" {
	# full instance profile that needs to be used by EC2 instances to access S3 bucket
	value = aws_iam_instance_profile.instance_profile
}