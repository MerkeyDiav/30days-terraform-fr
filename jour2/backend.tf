# Configuration du backend S3 pour le remote state
# IMPORTANT: Créez d'abord les ressources dans backend-setup/ avant d'activer ce backend
# 
# Instructions:
# 1. Aller dans backend-setup/ et lancer: terraform apply
# 2. Copier les valeurs de sortie (s3_bucket_name et dynamodb_table_name)
# 3. Décommenter et mettre à jour les valeurs ci-dessous
# 4. Lancer: terraform init (Terraform proposera de migrer le state)

# terraform {
#   backend "s3" {
#     bucket         = "hopesystem-terraform-state-VALEUR_ALEATOIRE"  # À remplacer après la création
#     key            = "jour2/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "hopesystem-terraform-locks"
#     encrypt        = true
#   }
# }

