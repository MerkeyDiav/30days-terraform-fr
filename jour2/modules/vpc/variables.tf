variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "Le VPC CIDR doit être au format valide (ex: 10.0.0.0/16)."
  }
  
  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 28
    error_message = "Le masque CIDR doit être entre /16 et /28."
  }
}

variable "public_azs" {
  description = "List of availability zones for public subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  
  validation {
    condition     = length(var.public_azs) >= 1 && length(var.public_azs) <= 6
    error_message = "Le nombre de zones de disponibilité publiques doit être entre 1 et 6."
  }
  
  validation {
    condition     = alltrue([for az in var.public_azs : can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))])
    error_message = "Chaque zone de disponibilité doit correspondre au format AWS (ex: us-east-1a)."
  }
}

variable "private_azs" {
  description = "List of availability zones for private subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  
  validation {
    condition     = length(var.private_azs) >= 1 && length(var.private_azs) <= 6
    error_message = "Le nombre de zones de disponibilité privées doit être entre 1 et 6."
  }
  
  validation {
    condition     = alltrue([for az in var.private_azs : can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))])
    error_message = "Chaque zone de disponibilité doit correspondre au format AWS (ex: us-east-1a)."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "L'environnement doit être l'un des suivants : dev, staging, prod, test."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform_challenge"
  
  validation {
    condition     = can(regex("^[a-z0-9_-]+$", var.project_name))
    error_message = "Le nom du projet doit contenir uniquement des lettres minuscules, chiffres, tirets et underscores."
  }
  
  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 50
    error_message = "Le nom du projet doit contenir entre 3 et 50 caractères."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = false
}

# Variables de personnalisation du comportement

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign public IP on launch for public subnets"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable IPv6 support for the VPC"
  type        = bool
  default     = false
}