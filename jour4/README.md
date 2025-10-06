# Jour 4 : Les Variables Locales (Locals) dans Terraform

## Introduction

Les variables locales (`locals`) sont un concept essentiel de Terraform qui permet de centraliser la logique interne des modules. Elles n'ont de portée que dans le module où elles sont définies, ce qui les rend idéales pour structurer le code et éviter les répétitions.

## Analogie avec la Programmation

Si nous comparons les modules Terraform à des fonctions dans d'autres langages de programmation :
- **Variables d'entrée** (`variables`) = Arguments de la fonction
- **Outputs** = Valeurs de retour de la fonction
- **Locals** = Variables internes à la fonction

Les `locals` représentent les variables internes utilisées uniquement pour effectuer des calculs ou structurer la logique, sans être visibles à l'extérieur du module.

## Syntaxe des Locals

### Déclaration

```hcl
locals {
  # Variables locales
  variable1 = "valeur1"
  variable2 = var.input_variable * 2
  variable3 = {
    key1 = "value1"
    key2 = "value2"
  }
}
```

### Caractéristiques Spéciales

1. **Pas de nom ni d'étiquette** : Le bloc `locals` ne porte pas de nom
2. **Multiples déclarations** : Peut être défini plusieurs fois dans un même module
3. **Variables indépendantes** : Chaque argument représente une variable locale indépendante

## Cas d'Usage Pratiques

### 1. Centralisation des Calculs CIDR

**Problème sans locals :**
```hcl
resource "aws_subnet" "public" {
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
}

resource "aws_subnet" "private" {
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.public_azs))
}
```

**Solution avec locals :**
```hcl
locals {
  public_subnet_cidrs = [
    for i in range(length(var.public_azs)) : 
    cidrsubnet(var.vpc_cidr, 8, i)
  ]
  
  private_subnet_cidrs = [
    for i in range(length(var.private_azs)) : 
    cidrsubnet(var.vpc_cidr, 8, i + length(var.public_azs))
  ]
}

resource "aws_subnet" "public" {
  cidr_block = local.public_subnet_cidrs[count.index]
}

resource "aws_subnet" "private" {
  cidr_block = local.private_subnet_cidrs[count.index]
}
```

### 2. Centralisation des Tags

**Problème sans locals :**
```hcl
resource "aws_vpc" "main" {
  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags)
}

resource "aws_internet_gateway" "main" {
  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-igw"
  })
}
```

**Solution avec locals :**
```hcl
locals {
  common_tags = {
    Name        = var.project_name
    Environment = var.environment
  }
  
  resource_names = {
    vpc = var.project_name
    igw = "${var.project_name}-igw"
  }
}

resource "aws_vpc" "main" {
  tags = merge(local.common_tags, var.tags)
}

resource "aws_internet_gateway" "main" {
  tags = merge(local.common_tags, var.tags, {
    Name = local.resource_names.igw
  })
}
```

### 3. Logique Complexe Centralisée

**Problème sans locals :**
```hcl
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0
}
```

**Solution avec locals :**
```hcl
locals {
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count
}

resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count
}
```

## Exemple Complet : Module VPC

### Structure des Locals

```hcl
locals {
  # Calculs CIDR centralisés
  public_subnet_cidrs = [
    for i in range(length(var.public_azs)) : 
    cidrsubnet(var.vpc_cidr, 8, i)
  ]
  
  private_subnet_cidrs = [
    for i in range(length(var.private_azs)) : 
    cidrsubnet(var.vpc_cidr, 8, i + length(var.public_azs))
  ]
  
  # Tags communs centralisés
  common_tags = {
    Name        = var.project_name
    Environment = var.environment
  }
  
  # Nomenclature centralisée
  resource_names = {
    vpc = var.project_name
    igw = "${var.project_name}-igw"
    nat_eip = "${var.project_name}-nat-eip"
    nat_gateway = "${var.project_name}-nat-gateway"
    public_subnet = "${var.project_name}-public"
    private_subnet = "${var.project_name}-private"
    public_rt = "${var.project_name}-public-rt"
    private_rt = "${var.project_name}-private-rt"
  }
  
  # Logique de comptage centralisée
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0
  
  # Configuration des subnets
  subnet_config = {
    public = {
      count = length(var.public_azs)
      cidrs = local.public_subnet_cidrs
      names = [for az in var.public_azs : "${local.resource_names.public_subnet}-${az}"]
    }
    private = {
      count = length(var.private_azs)
      cidrs = local.private_subnet_cidrs
      names = [for az in var.private_azs : "${local.resource_names.private_subnet}-${az}"]
    }
  }
}
```

### Utilisation dans les Ressources

```hcl
# Subnets publics simplifiés
resource "aws_subnet" "public" {
  count = local.subnet_config.public.count
  cidr_block = local.subnet_config.public.cidrs[count.index]
  availability_zone = var.public_azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, var.tags, {
    Name = local.subnet_config.public.names[count.index]
    Type = "public"
  })
}

# NAT Gateway simplifié
resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id = var.single_nat_gateway ? aws_subnet.public[0].id : aws_subnet.public[count.index].id

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.resource_names.nat_gateway}-${count.index + 1}"
    Type = "NAT Gateway"
  })
}
```

## Locals dans le Fichier Principal

```hcl
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
    single_nat_gateway = false
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
  
  enable_nat_gateway = local.nat_config.enable_nat_gateway
  single_nat_gateway = local.nat_config.single_nat_gateway
  
  tags = local.default_tags
}
```

## Avantages des Locals

### 1. Maintenabilité
- **Un seul endroit** pour modifier la logique
- **Évite les erreurs** de duplication
- **Facilite les refactorisations**

### 2. Lisibilité
- **Code plus clair** et structuré
- **Logique centralisée** et compréhensible
- **Séparation des préoccupations**

### 3. Performance
- **Calculs effectués une seule fois** par Terraform
- **Optimisation automatique** des expressions
- **Réduction de la complexité** du plan

### 4. Réutilisabilité
- **Logique centralisée** réutilisable
- **Configuration cohérente** dans tout le module
- **Facilite les tests** et la validation

## Bonnes Pratiques

### 1. Organisation
```hcl
locals {
  # Calculs et transformations
  computed_values = { ... }
  
  # Configuration et paramètres
  config = { ... }
  
  # Tags et métadonnées
  tags = { ... }
  
  # Noms et identifiants
  names = { ... }
}
```

### 2. Nommage
- Utiliser des noms **descriptifs** et **cohérents**
- Éviter les abréviations **cryptiques**
- Grouper par **fonctionnalité**

### 3. Documentation
```hcl
locals {
  # Calculs CIDR pour les subnets publics et privés
  # Évite la duplication de la logique cidrsubnet()
  subnet_cidrs = { ... }
  
  # Tags communs à toutes les ressources
  # Centralise la logique de tagging
  common_tags = { ... }
}
```

## Limitations et Considérations

### 1. Portée
- Les `locals` ne sont **visibles que dans le module** où ils sont définis
- **Pas d'accès direct** depuis l'extérieur
- **Partage via outputs** si nécessaire

### 2. Dépendances
- Les `locals` peuvent **dépendre d'autres locals**
- Attention aux **dépendances circulaires**
- **Ordre de déclaration** important

### 3. Performance
- Éviter les **calculs complexes** dans les locals
- **Préférer la simplicité** à l'optimisation prématurée
- **Tester les performances** sur de gros projets

## Conclusion

Les `locals` sont un outil puissant pour structurer et organiser le code Terraform. Ils permettent de :

- **Centraliser la logique** interne des modules
- **Éviter les répétitions** et améliorer la maintenabilité
- **Clarifier le code** et faciliter la compréhension
- **Optimiser les performances** en évitant les calculs redondants

En utilisant les `locals` de manière appropriée, vous créez des modules plus robustes, maintenables et efficaces, tout en respectant les bonnes pratiques de développement Terraform.