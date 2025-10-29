# Setup du Backend Remote State

Ce dossier contient la configuration Terraform pour créer les ressources AWS nécessaires au remote state de notre infrastructure.

## Ressources Créées

- **S3 Bucket** : Stockage du fichier `terraform.tfstate` avec versioning et chiffrement
- **DynamoDB Table** : Gestion des verrous pour éviter les conflits lors des déploiements simultanés

## Utilisation

### 1. Initialiser et Déployer

```bash
cd backend-setup/
terraform init
terraform plan
terraform apply
```

### 2. Récupérer les Informations

Après le déploiement, notez les outputs :

```bash
terraform output s3_bucket_name
terraform output dynamodb_table_name
```

### 3. Configurer le Backend dans jour2/

1. Ouvrir `../jour2/backend.tf`
2. Décommenter la section `terraform { backend "s3" { ... } }`
3. Remplacer les valeurs :
   - `bucket` : Utiliser la valeur de `s3_bucket_name`
   - `dynamodb_table` : Utiliser la valeur de `dynamodb_table_name`

### 4. Migrer le State Local vers S3

```bash
cd ../jour2/
terraform init
# Terraform détectera le changement et proposera la migration
# Répondre "yes" pour migrer le state local vers S3
```

## Sécurité

- Le bucket S3 est privé (pas d'accès public)
- Chiffrement AES-256 activé
- Versioning activé pour l'historique
- Verrous DynamoDB pour éviter les conflits

