# Variables locales pour centraliser la configuration
locals {
  # Configuration VPC centralisée
  vpc_config = {
    cidr = "10.0.0.0/16"
    public_azs = ["us-east-1a", "us-east-1b"]
    private_azs = ["us-east-1a", "us-east-1b"]
    environment = "dev"
    project_name = "terraform_challenge"
  }
  
  # Configuration NAT Gateway
  nat_config = {
    enable_nat_gateway = true
    single_nat_gateway = false  # true pour économiser (1 NAT Gateway pour tous les subnets privés)
  }
  
  # Tags par défaut
  default_tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Backup      = "daily"
    Monitoring  = "enabled"
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = local.vpc_config.cidr
  public_azs = local.vpc_config.public_azs
  private_azs = local.vpc_config.private_azs
  environment = local.vpc_config.environment
  project_name = local.vpc_config.project_name
  
  # Configuration NAT Gateway avec expressions
  enable_nat_gateway = local.nat_config.enable_nat_gateway
  single_nat_gateway = local.nat_config.single_nat_gateway
  
  # Exemple d'utilisation des tags personnalisés
  tags = local.default_tags
}