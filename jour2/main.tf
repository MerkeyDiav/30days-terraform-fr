module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"
  public_azs = ["us-east-1a", "us-east-1b"]
  private_azs = ["us-east-1a", "us-east-1b"]
  environment = "dev"
  project_name = "terraform_challenge"
}