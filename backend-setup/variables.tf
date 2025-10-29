variable "aws_region" {
  description = "Région AWS pour le bucket S3 et la table DynamoDB"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nom du projet (utilisé pour nommer les ressources)"
  type        = string
  default     = "hopesystem"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "production"
}

