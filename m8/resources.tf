###### PROVIDERS ############
provider "aws" {
  # Not needed if creds are passed as env vars
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  region     = var.region
}

# provider "azurerm" {
#   subscription_id = var.arm_subscription_id
#   client_id = var.arm_principal
#   client_secret = var.arm_password
#   tenant_id = var.tenant_id
#   alias = "arm-1"
#   features {}
# }



###### DATA ##########
# to get the list of AZs
data "aws_availability_zones" "available" {}

data "aws_ami" "aws_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "public_cidrsubnet" {
  count = var.subnet_count[terraform.workspace]

  # will create 2 text strings
  template = "$${cidrsubnet(vpc_cidr,8,current_count)}"

  vars = {
    vpc_cidr = var.network_address_space[terraform.workspace]
    current_count = count.index
  }
}

####### RESOURCES #########

# PUBLIC KEY #
resource "aws_key_pair" "pluralsightkey" {
  key_name = "PluralsightKeys"
  public_key = file("/Users/dnatochy/Downloads/PluralsightKeys-pub.pem")
}

#Random ID
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

## NETWORKING ##
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "${local.env_name}-vpc"
  version = "2.15.0"
  
  cidr           = var.network_address_space[terraform.workspace]
  # list of AZs
  azs = slice(data.aws_availability_zones.available.names,0,var.subnet_count[terraform.workspace])
  public_subnets = data.template_file.public_cidrsubnet[*].rendered
  private_subnets = []

  tags = local.common_tags
}

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.vpc.id

#   tags = merge(local.common_tags, { Name = "${local.env_name}-igw" })
# }

# resource "aws_subnet" "subnet" {
#   # how many instances of this resource we want to create
#   count = var.subnet_count[terraform.workspace]
#   # subnet will be determined by the count value
#   cidr_block = cidrsubnet(var.network_address_space[terraform.workspace], 8, count.index)
#   vpc_id     = aws_vpc.vpc.id
#   # instances deployed in this subnet will get a public IP
#   map_public_ip_on_launch = "true"
#   availability_zone       = data.aws_availability_zones.available.names[count.index]

#   tags = merge(local.common_tags, { Name = "${local.env_name}-subnet${count.index+1}" })
# }


# # ROUTING #
# resource "aws_route_table" "rtb" {
#   vpc_id = aws_vpc.vpc.id
#   # default route out of the VPC will point to the Internet Gateway
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
# }

# resource "aws_route_table_association" "rta-subnet" {
#   count = var.subnet_count[terraform.workspace]
#   subnet_id      = aws_subnet.subnet[count.index].id
#   route_table_id = aws_route_table.rtb.id
# }

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  name   = "nginx_elb_sg"
  # have to refer to the resource using "module"
  vpc_id = module.vpc.vpc_id

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "nginx-sg" {
  name   = "nginx_sg"
  vpc_id = module.vpc.vpc_id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    #   cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = [var.network_address_space[terraform.workspace]]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# LOAD BALANCER #
resource "aws_elb" "web" {
  name = "${local.env_name}-nginx-elb"

  # updated to use vpc module
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.elb-sg.id]
  instances = aws_instance.nginx[*].id

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# INSTANCES #
resource "aws_instance" "nginx" {
  count = var.instance_count[terraform.workspace]
  ami                    = data.aws_ami.aws_linux.id
  instance_type          = var.instance_size[terraform.workspace]
  # odd instances will end up in subnet 1, even - in subnet 2
  # updated to use vpc module
  subnet_id = module.vpc.public_subnets[count.index % var.subnet_count[terraform.workspace]]
  vpc_security_group_ids = [aws_security_group.nginx-sg.id]
  key_name               = var.key_name
  # to grant access to S3 bucket
  # updated to use bucket module
  iam_instance_profile = module.bucket.instance_profile.name
  depends_on = [
    module.bucket
  ]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content = <<EOF
      access_key = ${var.AWS_ACCESS_KEY_ID}
      secret_key = ${var.AWS_SECRET_ACCESS_KEY}
      security_token =
      use_https = True
      bucket_location = US

      EOF

    destination = "/home/ec2-user/.s3cfg"
  }

  provisioner "file" {
    content = <<EOF
    /var/log/nginx/*log {
      daily
      rotate 10
      missingok
      compress
      sharedscripts
      postrotate
      endscript
      lastaction
        INSTANCE_ID=`curl --silent http://169.254.169.254/latest/meta-data/instance-id`
        sudo /usr/local/bin/s3cmd sync --config=/home/ec2-user/.s3cfg /var/log/nginx s3://${module.bucket.bucket.id}/nginx/$INSTANCE_ID/
      endscript
    }

    EOF

    destination = "/home/ec2-user/nginx"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "sudo cp /home/ec2-user/.s3cfg /root/.s3cfg",
      "sudo cp /home/ec2-user/nginx /etc/logrotate.d/nginx",
      "sudo pip install s3cmd",
      "s3cmd get s3://${module.bucket.bucket.id}/website/index.html .",
      "s3cmd get s3://${module.bucket.bucket.id}/website/Globo_logo_Vert.png .",
      "sudo cp /home/ec2-user/index.html /usr/share/nginx/html/index.html",
      "sudo cp /home/ec2-user/Globo_logo_Vert.png /usr/share/nginx/html/Globo_logo_Vert.png",
      "sudo logrotate -f /etc/logrotate.conf"
    ]
  }

  tags = merge(local.common_tags, { Name = "${local.env_name}-nginx${count.index + 1}" })
}

# S3 Bucket config#
module "bucket" {
  name = local.s3_bucket_name

  source = "./Modules/s3"
  common_tags = local.common_tags
}

resource "aws_s3_bucket_object" "website" {
  # bucket (module). bucket (from outputs.tf in bucket module)
  bucket = module.bucket.bucket.id
  key    = "/website/index.html"
  source = "./index.html"
}

# create an object in S3 bucket
resource "aws_s3_bucket_object" "graphic" {
  bucket = module.bucket.bucket.id
  # the key where the file should be stored
  key    = "/website/Globo_logo_Vert.png"
  source = "./Globo_logo_Vert.png"
}


# Azure RM DNS #
# resource "azurerm_dns_cname_record" "elb" {
#   name = "${local.env_name}-website"
#   zone_name = var.dns_zone_name
#   resource_group_name = var.dns_resource_group
#   ttl = "30"
#   record = aws_elb.web.dns_name
#   provider = azurerm.arm-1

#   tags = merge(local.common_tags, { Name = "${local.env_name}-website" })
# }

######## OUTPUT ###########
output "aws_instance_public_dns" {
  value = aws_elb.web.dns_name
}