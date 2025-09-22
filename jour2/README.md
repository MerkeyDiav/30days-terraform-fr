# Jour 2 – Premier module Terraform : VPC AWS

> **Challenge 30 jours pour apprendre Terraform en français**

Bienvenue dans le **Jour 2** ! Aujourd'hui, nous allons créer notre premier module Terraform pour déployer un VPC (Virtual Private Cloud) sur AWS.

---

## Objectifs du jour

- Créer un module Terraform réutilisable pour un VPC AWS
- Comprendre la structure d'un module Terraform
- Déployer des ressources AWS avec Terraform
- Apprendre à utiliser les variables et outputs

---

## Structure du projet

```
jour2/
├── main.tf                 # Configuration principale
├── provider.tf            # Configuration du provider AWS
├── modules/
│   └── vpc/
│       ├── main.tf        # Ressources du VPC
│       ├── variables.tf   # Variables d'entrée
│       └── outputs.tf     # Valeurs de sortie
└── README.md              # Ce fichier
```

---

## Configuration du provider AWS

Avant de commencer, vous devez configurer vos credentials AWS. Créez un fichier `provider.tf` :

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

**Important** : Configurez vos credentials AWS avec l'une de ces méthodes :
- Variables d'environnement : `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY`
- Fichier `~/.aws/credentials`
- AWS CLI configuré avec `aws configure`

---

## Module VPC

### Variables disponibles

Le module VPC accepte les variables suivantes :

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `vpc_cidr` | string | "10.0.0.0/16" | CIDR block du VPC |
| `public_azs` | list(string) | ["us-east-1a", "us-east-1b"] | Zones de disponibilité pour subnets publics |
| `private_azs` | list(string) | ["us-east-1a", "us-east-1b"] | Zones de disponibilité pour subnets privés |
| `environment` | string | "dev" | Nom de l'environnement |
| `project_name` | string | "terraform_challenge" | Nom du projet |

### Ressources créées

Le module crée automatiquement :

- **1 VPC** avec DNS hostnames et support activés
- **1 Internet Gateway** pour l'accès internet
- **Subnets publics** (un par AZ spécifiée) avec accès internet
- **Subnets privés** (un par AZ spécifiée) sans accès internet direct
- **Route Tables** séparées pour les subnets publics et privés
- **Associations** entre les route tables et les subnets

### Outputs disponibles

Le module expose les valeurs suivantes :

- `vpc_id` : ID du VPC créé
- `public_subnet_ids` : Liste des IDs des subnets publics
- `private_subnet_ids` : Liste des IDs des subnets privés
- `internet_gateway_id` : ID de l'Internet Gateway
- `public_route_table_id` : ID de la route table publique
- `private_route_table_id` : ID de la route table privée

---

## Utilisation du module

### 1. Configuration de base

Créez un fichier `main.tf` dans le répertoire `jour2/` :

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr     = "10.0.0.0/16"
  public_azs   = ["us-east-1a", "us-east-1b"]
  private_azs  = ["us-east-1a", "us-east-1b"]
  environment  = "dev"
  project_name = "terraform_challenge"
}
```

### 2. Initialisation

```bash
terraform init
```

Cette commande :
- Télécharge le provider AWS
- Initialise le module VPC
- Configure le backend local

### 3. Planification

```bash
terraform plan
```

Cette commande vous montre exactement quelles ressources vont être créées sans les créer.

### 4. Déploiement

```bash
terraform apply
```

Tapez `yes` quand Terraform vous demande confirmation.

### 5. Vérification

```bash
terraform show
```

Cette commande affiche l'état actuel de vos ressources.

---

## Commandes utiles

### Voir les outputs du module

```bash
terraform output
```

### Voir les détails d'une ressource

```bash
terraform show
```

### Détruire les ressources

```bash
terraform destroy
```

**Attention** : Cette commande supprime définitivement toutes les ressources créées.

---

## Personnalisation avancée

### Utiliser des zones de disponibilité différentes

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr     = "172.16.0.0/16"
  public_azs   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_azs  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  environment  = "production"
  project_name = "mon_projet"
}
```

### Utiliser les outputs dans d'autres modules

```hcl
module "vpc" {
  source = "./modules/vpc"
  # ... configuration ...
}

# Utiliser l'ID du VPC dans un autre module
module "ec2" {
  source = "./modules/ec2"
  
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}
```

---

## Dépannage

### Erreur de credentials AWS

```
Error: No valid credential sources found
```

**Solution** : Configurez vos credentials AWS avec `aws configure` ou les variables d'environnement.

### Erreur de région

```
Error: Invalid region
```

**Solution** : Vérifiez que la région spécifiée dans `provider.tf` est valide et accessible.

### Erreur de CIDR

```
Error: Invalid CIDR block
```

**Solution** : Vérifiez que le CIDR du VPC est valide (ex: "10.0.0.0/16").

---

## Prochaines étapes

Dans le **Jour 3**, nous apprendrons à :
- Créer des instances EC2 dans notre VPC
- Configurer des groupes de sécurité
- Utiliser les outputs du module VPC

---

## Ressources utiles

- [Documentation Terraform - Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Documentation AWS Provider - VPC](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
- [Documentation AWS Provider - Subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)

---

<div align="center">

**[⬅ Jour 1](../jour1/README.md) **

*Challenge 30 jours Terraform - Jour 2/30*

</div>
