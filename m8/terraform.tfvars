### one of the way to define variables in terraform
# aws_access_key = "{access_key}"
# aws_secret_key = "{secret_key}"

key_name         = "PluralsightKeys"
private_key_path = "/Users/dnatochy/Downloads/PluralsightKeys.pem"

bucket_name_prefix = "globo"
environment_tag    = "dev"
billing_code_tag   = "ACCT8675309"

arm_subscription_id = "{sub_id}"
arm_principal = "{principal}"
arm_password = "{password}"
tenant_id = "{tenant_id}" # output of az login
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