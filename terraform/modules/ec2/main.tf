resource "aws_instance" "blue" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_a_id
  vpc_security_group_ids = [var.ec2_sg_id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name = "${var.project_name}-blue"
  }
}

resource "aws_instance" "green" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_b_id
  vpc_security_group_ids = [var.ec2_sg_id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name = "${var.project_name}-green"
  }
}