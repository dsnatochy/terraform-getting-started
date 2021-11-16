### one of the way to define variables in terraform
# aws_access_key = "AKIATB4FGGFWZFP3W4EK"
# aws_secret_key = "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"

key_name         = "PluralsightKeys"
private_key_path = "/Users/dnatochy/Downloads/PluralsightKeys.pem"

bucket_name_prefix = "globo"
environment_tag    = "dev"
billing_code_tag   = "ACCT8675309"

arm_subscription_id = "4cedc5dd-e3ad-468d-bf66-32e31bdb9148"
arm_principal = "cloud_user_p_23cceb91@azurelabs.linuxacademy.com"
arm_password = "QNNnogeotPGmqn5!dp31"
tenant_id = "3617ef9b-98b4-40d9-ba43-e1ed6709cf0d" # output of az login
dns_zone_name = "globomantics.xyz"
dns_resource_group = "dns"

network_address_space = {
  Development   = "10.0.0.0/16"
  UAT = "10.1.0.0/16"
  Production = "10.2.0.0/16"
}

instance_size = {
  Development = "t2.micro"
  UAT = "t2.small"
  Production = "t2.medium"
}

subnet_count = {
  Development = 2
  UAT = 2
  Production = 3
}

instance_count = {
  Development = 2
  UAT = 4
  Production = 6
}