# Module EC2

Module Terraform pour créer une instance EC2 avec validation des variables d'entrée.

## Description

Ce module démontre l'utilisation des variables d'entrée pour personnaliser le comportement sans modifier le code. Il illustre parfaitement :
- La restriction des types de variables
- La validation de format avec expressions régulières
- La validation de liste de valeurs autorisées

## Variables d'entrée

| Variable | Type | Défaut | Description | Validation |
|----------|------|--------|-------------|------------|
| `instance_type` | string | "t3.micro" | Type d'instance EC2 | Doit être dans la liste : t2.micro, t2.small, t3.micro, t3.small, t3.medium |
| `subnet_id` | string | - | ID du subnet où lancer l'instance | Format AWS : `^subnet-[\\d\|\\w]+$` |
| `vpc_id` | string | - | ID du VPC pour le security group | Format AWS : `^vpc-[\\d\|\\w]+$` |
| `ami_id` | string | "" | ID de l'AMI (vide = Ubuntu 22.04 latest) | Format AWS : `^ami-[\\d\|\\w]+$` ou vide |
| `instance_name` | string | "terraform-ec2-instance" | Nom de l'instance | Entre 3 et 100 caractères |
| `enable_public_ip` | bool | true | Activer l'IP publique | - |
| `enable_iam_role` | bool | true | Créer un rôle IAM pour l'instance | - |
| `iam_role_name` | string | "" | Nom personnalisé du rôle IAM (vide = auto) | - |
| `tags` | map(string) | {} | Tags additionnels | - |

## Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | ID de l'instance EC2 |
| `instance_public_ip` | Adresse IP publique |
| `instance_private_ip` | Adresse IP privée |
| `security_group_id` | ID du security group |
| `instance_arn` | ARN de l'instance |
| `ami_used` | ID de l'AMI utilisée |
| `iam_role_name` | Nom du rôle IAM |
| `iam_role_arn` | ARN du rôle IAM |
| `iam_role` | Objet complet du rôle IAM |

## Ressources créées

- 1 Instance EC2
- 1 Security Group avec règles :
  - SSH (port 22) depuis n'importe où
  - HTTP (port 80) depuis n'importe où
  - HTTPS (port 443) depuis n'importe où
  - Tout le trafic sortant autorisé
- 1 Rôle IAM (optionnel, activé par défaut)
- 1 Instance Profile IAM (optionnel, activé par défaut)

## Utilisation

### Exemple de base

```hcl
module "ec2_web" {
  source = "./modules/ec2"
  
  instance_type = "t3.micro"
  subnet_id     = "subnet-12345678"
  vpc_id        = "vpc-87654321"
  instance_name = "my-web-server"
}
```

### Exemple avec module VPC

```hcl
module "vpc" {
  source = "./modules/vpc"
  # ... configuration VPC
}

module "ec2_web" {
  source = "./modules/ec2"
  
  instance_type    = "t3.micro"
  subnet_id        = module.vpc.public_subnet_ids[0]
  vpc_id           = module.vpc.vpc_id
  instance_name    = "web-server"
  enable_public_ip = true
  
  tags = {
    Role = "WebServer"
    Tier = "Frontend"
  }
}
```

### Exemple avec AMI personnalisée

```hcl
module "ec2_custom" {
  source = "./modules/ec2"
  
  instance_type = "t3.small"
  subnet_id     = module.vpc.private_subnet_ids[0]
  vpc_id        = module.vpc.vpc_id
  ami_id        = "ami-0c55b159cbfafe1f0"
  instance_name = "custom-app-server"
  enable_public_ip = false
}
```

### Exemple avec IAM et accès S3

```hcl
# Créer l'instance avec un rôle IAM
module "ec2_data_processor" {
  source = "./modules/ec2"
  
  instance_type    = "t3.micro"
  subnet_id        = module.vpc.private_subnet_ids[0]
  vpc_id           = module.vpc.vpc_id
  instance_name    = "data-processor"
  enable_iam_role  = true
  enable_public_ip = false
  
  tags = {
    Application = "DataProcessing"
    Environment = "Production"
  }
}

# Créer une politique personnalisée pour l'accès S3
resource "aws_iam_policy" "s3_data_access" {
  name        = "data-processor-s3-policy"
  description = "Permet l'accès au bucket de données"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::mon-bucket-data/*",
          "arn:aws:s3:::mon-bucket-data"
        ]
      }
    ]
  })
}

# Attacher la politique au rôle de l'instance
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = module.ec2_data_processor.iam_role_name
  policy_arn = aws_iam_policy.s3_data_access.arn
}
```

### Exemple avec multiples politiques IAM

```hcl
module "ec2_app" {
  source = "./modules/ec2"
  
  instance_type   = "t3.small"
  subnet_id       = module.vpc.private_subnet_ids[0]
  vpc_id          = module.vpc.vpc_id
  instance_name   = "application-server"
  iam_role_name   = "app-server-role"
}

# Politique pour S3
resource "aws_iam_policy" "s3_policy" {
  name = "app-s3-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::mon-bucket/*"
    }]
  })
}

# Politique pour DynamoDB
resource "aws_iam_policy" "dynamodb_policy" {
  name = "app-dynamodb-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = "arn:aws:dynamodb:*:*:table/ma-table"
    }]
  })
}

# Politique pour Secrets Manager
resource "aws_iam_policy" "secrets_policy" {
  name = "app-secrets-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:app/*"
    }]
  })
}

# Attacher toutes les politiques
resource "aws_iam_role_policy_attachment" "attach_s3" {
  role       = module.ec2_app.iam_role_name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_dynamodb" {
  role       = module.ec2_app.iam_role_name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_secrets" {
  role       = module.ec2_app.iam_role_name
  policy_arn = aws_iam_policy.secrets_policy.arn
}
```

### Exemple sans rôle IAM

```hcl
module "ec2_bastion" {
  source = "./modules/ec2"
  
  instance_type    = "t3.micro"
  subnet_id        = module.vpc.public_subnet_ids[0]
  vpc_id           = module.vpc.vpc_id
  instance_name    = "bastion-host"
  enable_iam_role  = false  # Pas de rôle IAM nécessaire
  enable_public_ip = true
}
```

## Validation des variables

### Exemples de validations réussies

```hcl
# ✓ Type d'instance valide
instance_type = "t3.micro"

# ✓ Format subnet_id correct
subnet_id = "subnet-0ab12cd34ef56gh78"

# ✓ Format vpc_id correct
vpc_id = "vpc-9ij87kl65mn43op21"
```

### Exemples d'erreurs de validation

```hcl
# ✗ Type d'instance non autorisé
instance_type = "m5.24xlarge"
# Erreur : Le type d'instance doit être l'un des suivants : t2.micro, t2.small, t3.micro, t3.small, t3.medium.

# ✗ Format subnet_id invalide
subnet_id = "invalid-subnet"
# Erreur : Le subnet_id doit correspondre au format AWS ^subnet-[\d|\w]+$

# ✗ Nom trop court
instance_name = "x"
# Erreur : Le nom de l'instance doit contenir entre 3 et 100 caractères.
```

## Sécurité

**Attention** : Le security group créé autorise SSH, HTTP et HTTPS depuis n'importe où (0.0.0.0/0). En production, restreignez l'accès :

- SSH uniquement depuis votre IP ou VPN
- HTTP/HTTPS uniquement depuis un Load Balancer
- Utilisez des security groups séparés pour différents niveaux

## AMI par défaut

Si `ami_id` n'est pas spécifié, le module utilise automatiquement la dernière AMI Ubuntu 22.04 LTS (Jammy) officielle de Canonical.

## Notes

- L'instance utilise le premier subnet public par défaut
- Le security group est créé automatiquement dans le VPC spécifié
- Les tags sont fusionnés avec les tags par défaut du module


