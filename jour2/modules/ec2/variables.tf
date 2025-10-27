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
    condition     = startswith(var.subnet_id, "subnet-") && length(var.subnet_id) > 7
    error_message = "Le subnet_id doit commencer par 'subnet-' et avoir une longueur suffisante."
  }
}

variable "vpc_id" {
  description = "L'ID du VPC pour le security group"
  type        = string
  
  validation {
    condition     = startswith(var.vpc_id, "vpc-") && length(var.vpc_id) > 4
    error_message = "Le vpc_id doit commencer par 'vpc-' et avoir une longueur suffisante."
  }
}

variable "ami_id" {
  description = "ID de l'AMI à utiliser pour l'instance"
  type        = string
  default     = ""
  
  validation {
    condition     = var.ami_id == "" || (startswith(var.ami_id, "ami-") && length(var.ami_id) > 4)
    error_message = "L'ami_id doit commencer par 'ami-' et avoir une longueur suffisante, ou être vide."
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

variable "enable_iam_role" {
  description = "Activer la création d'un rôle IAM pour l'instance"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Nom du rôle IAM (optionnel, utilise instance_name par défaut)"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Activer l'agent de monitoring CloudWatch"
  type        = bool
  default     = false
}

variable "monitoring_config" {
  description = "Configuration du monitoring"
  type        = object({
    log_group = string
    region    = string
  })
  default = {
    log_group = "/aws/ec2"
    region    = "us-east-1"
  }
}

variable "user_data_script" {
  description = "Chemin vers un script user_data personnalisé (optionnel)"
  type        = string
  default     = ""
}

