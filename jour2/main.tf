module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"
  public_azs = ["us-east-1a", "us-east-1b"]
  private_azs = ["us-east-1a", "us-east-1b"]
  environment = "dev"
  project_name = "terraform_challenge"
  
  # Configuration NAT Gateway avec expressions
  enable_nat_gateway = true
  single_nat_gateway = false  # true pour économiser (1 NAT Gateway pour tous les subnets privés)
  
  # Exemple d'utilisation des tags personnalisés
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Backup      = "daily"
    Monitoring  = "enabled"
  }
}