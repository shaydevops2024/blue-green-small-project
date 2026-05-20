project_name  = "blue-green-small"
aws_region    = "us-east-1"
vpc_cidr      = "10.0.0.0/16"
subnet_a_cidr = "10.0.1.0/24"
subnet_b_cidr = "10.0.2.0/24"
db_name       = "appdb"
db_username   = "appuser"
# db_password — set via TF_VAR_db_password env var, do not commit here
