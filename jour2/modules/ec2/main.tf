# Data source pour récupérer l'AMI Ubuntu la plus récente si non spécifiée
data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] #

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Policy document pour permettre à EC2 d'assumer le rôle IAM
# Cette politique indique à AWS que le service EC2 est autorisé à utiliser ce rôle
data "aws_iam_policy_document" "instance_assume_role_policy" {
  count = var.enable_iam_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Création du rôle IAM pour l'instance
# Ce rôle servira de conteneur pour les politiques que les utilisateurs voudront attacher
resource "aws_iam_role" "instance_role" {
  count = var.enable_iam_role ? 1 : 0

  name               = var.iam_role_name != "" ? var.iam_role_name : "${var.instance_name}-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy[0].json

  tags = merge(var.tags, {
    Name = var.iam_role_name != "" ? var.iam_role_name : "${var.instance_name}-role"
  })
}

# Instance Profile : le pont entre le rôle IAM et l'instance EC2
# AWS nécessite cette ressource intermédiaire pour attacher un rôle à une instance
resource "aws_iam_instance_profile" "instance_profile" {
  count = var.enable_iam_role ? 1 : 0

  name = aws_iam_role.instance_role[0].name
  role = aws_iam_role.instance_role[0].name

  tags = merge(var.tags, {
    Name = "${var.instance_name}-profile"
  })
}

# Security Group pour l'instance EC2
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.instance_name}-sg-"
  description = "Security group pour l'instance EC2 ${var.instance_name}"
  vpc_id      = var.vpc_id

  # SSH depuis n'importe où (à restreindre en production)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP depuis n'importe où
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS depuis n'importe où
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tout le trafic sortant autorisé
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Instance EC2
resource "aws_instance" "main" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = var.enable_public_ip
  # User data : script personnalisé ou template par défaut
  user_data = var.user_data_script != "" ? file(var.user_data_script) : templatefile("${path.module}/templates/cloud-init.tftpl", {
    instance_name     = var.instance_name
    enable_monitoring = var.enable_monitoring
    log_group         = var.monitoring_config.log_group
    region            = var.monitoring_config.region
    iam_role_arn      = var.enable_iam_role ? aws_iam_role.instance_role[0].arn : ""
  })
  
  # Attachement du profil IAM si activé
  iam_instance_profile        = var.enable_iam_role ? aws_iam_instance_profile.instance_profile[0].name : null

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

