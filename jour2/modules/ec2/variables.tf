variable "instance_type" {
  description = "Type d'instance EC2 à lancer"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = contains(["t2.micro", "t2.small", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Le type d'instance doit être l'un des suivants : t2.micro, t2.small, t3.micro, t3.small, t3.medium."
  }
}

variable "subnet_id" {
  description = "L'ID du Subnet où lancer l'instance"
  type        = string
  
  validation {
    condition     = length(regexall("^subnet-[\\d|\\w]+$", var.subnet_id)) == 1
    error_message = "Le subnet_id doit correspondre au format AWS ^subnet-[\\d|\\w]+$"
  }
}

variable "vpc_id" {
  description = "L'ID du VPC pour le security group"
  type        = string
  
  validation {
    condition     = length(regexall("^vpc-[\\d|\\w]+$", var.vpc_id)) == 1
    error_message = "Le vpc_id doit correspondre au format AWS ^vpc-[\\d|\\w]+$"
  }
}

variable "ami_id" {
  description = "ID de l'AMI à utiliser pour l'instance"
  type        = string
  default     = ""
  
  validation {
    condition     = var.ami_id == "" || length(regexall("^ami-[\\d|\\w]+$", var.ami_id)) == 1
    error_message = "L'ami_id doit correspondre au format AWS ^ami-[\\d|\\w]+$ ou être vide."
  }
}

variable "instance_name" {
  description = "Nom de l'instance EC2"
  type        = string
  default     = "terraform-ec2-instance"
  
  validation {
    condition     = length(var.instance_name) >= 3 && length(var.instance_name) <= 100
    error_message = "Le nom de l'instance doit contenir entre 3 et 100 caractères."
  }
}

variable "enable_public_ip" {
  description = "Activer l'assignation d'une IP publique"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags additionnels à appliquer à l'instance"
  type        = map(string)
  default     = {}
}

