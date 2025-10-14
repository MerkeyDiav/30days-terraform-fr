# Jour 5 : Personnaliser et sécuriser nos modules Terraform grâce aux variables d'entrée

## Introduction

Lors de la création de modules Terraform réutilisables, deux aspects sont cruciaux :

1. **Sécurité** : S'assurer que les valeurs d'entrée sont valides avant l'exécution
2. **Personnalisation** : Offrir la flexibilité de modifier le comportement sans éditer le module

Les variables d'entrée mal configurées peuvent entraîner :
- Des pannes de service (outages)
- Des incidents de sécurité
- Des erreurs difficiles à tracer
- Une expérience utilisateur frustrante

Terraform offre un mécanisme puissant de **validation des inputs** qui permet de détecter les erreurs **avant** l'exécution du `terraform apply`.

---

## Partie 1 : Validation des Variables d'Entrée

### Pourquoi valider les inputs ?

En programmation, la validation des entrées est essentielle. Avec Terraform, le risque principal n'est pas la compromission de sécurité, mais plutôt :

- **Mauvaise configuration** des systèmes
- **Temps perdu** avec des erreurs détectées tardivement
- **Difficultés de débogage** quand une valeur invalide se propage

> **Point clé** : `terraform plan` et `terraform apply` peuvent prendre beaucoup de temps. Certaines erreurs ne sont même pas détectées pendant la phase `plan`. Détecter les problèmes tôt est donc **crucial**.

### Le bloc `validation`

Le bloc `validation` est une sous-section du bloc `variable` qui permet de définir des règles de validation.

#### Syntaxe de base

```hcl
variable "nom_variable" {
  description = "Description de la variable"
  type        = string
  
  validation {
    condition     = <expression_booléenne>
    error_message = "Message d'erreur si la condition échoue."
  }
}
```

#### Composants du bloc validation

| Champ | Description |
|-------|-------------|
| `condition` | Expression qui doit être évaluée à `true` ou `false` |
| `error_message` | Message affiché si la condition échoue |

#### Règles pour les messages d'erreur

Selon la documentation Terraform, les messages d'erreur doivent :
- Contenir **au moins une phrase complète en anglais** (ou français)
- Commencer par une **lettre majuscule**
- Se terminer par un **point ou un point d'interrogation**

---

## Cas d'Usage de Validation

### 1. Validation Simple : Longueur de Chaîne

**Problème** : Éviter qu'un nom soit trop long pour AWS (limite de 125 caractères).

```hcl
variable "description" {
  description = "Description optionnelle des ressources"
  type        = string
  default     = ""
  
  validation {
    condition     = length(var.description) <= 125
    error_message = "La description ne peut pas dépasser 125 caractères."
  }
}
```

### 2. Validations Multiples sur la Même Variable

**Problème** : S'assurer qu'un nombre est un entier entre 0 et 10.

```hcl
variable "my_integer" {
  description = "Un entier entre 0 et 10 inclus"
  type        = number
  
  validation {
    condition     = var.my_integer <= 10
    error_message = "La valeur ne doit pas dépasser 10."
  }
  
  validation {
    condition     = var.my_integer >= 0
    error_message = "La valeur ne doit pas être inférieure à 0."
  }
  
  validation {
    condition     = can(parseint(tostring(var.my_integer), 10))
    error_message = "La valeur doit être un entier."
  }
}
```

### 3. Validation avec Regex : Format de Subnet ID

**Problème** : AWS attend un format spécifique pour les subnet IDs (`subnet-xxxxx`).

```hcl
variable "subnet_id" {
  description = "L'ID du Subnet où lancer l'instance"
  type        = string
  
  validation {
    condition     = length(regexall("^subnet-[\\d|\\w]+$", var.subnet_id)) == 1
    error_message = "Le subnet_id doit correspondre au format ^subnet-[\\d|\\w]+$"
  }
}
```

### 4. Validation d'Environnement avec `contains()`

**Problème** : Restreindre les valeurs à une liste prédéfinie.

```hcl
variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être l'un des suivants : dev, staging, prod."
  }
}
```

### 5. Validation CIDR avec Regex et Plage

**Problème** : Valider le format ET la plage du CIDR block.

```hcl
variable "vpc_cidr" {
  description = "CIDR block du VPC"
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
```

### 6. Validation de Liste avec `alltrue()`

**Problème** : Valider que tous les éléments d'une liste respectent un format.

```hcl
variable "public_azs" {
  description = "Liste des zones de disponibilité pour les subnets publics"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  
  validation {
    condition     = length(var.public_azs) >= 1 && length(var.public_azs) <= 6
    error_message = "Le nombre de zones de disponibilité doit être entre 1 et 6."
  }
  
  validation {
    condition     = alltrue([for az in var.public_azs : can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))])
    error_message = "Chaque zone de disponibilité doit correspondre au format AWS (ex: us-east-1a)."
  }
}
```

---

## Partie 2 : Personnalisation du Comportement

### Principe de Personnalisation

Les variables d'entrée permettent aux utilisateurs de **modifier le comportement du module** sans en éditer le code source.

**Objectifs :**
- Rendre le module **réutilisable**
- Offrir de la **flexibilité**
- Maintenir des **valeurs par défaut sensées**
- Éviter la duplication de code

### Cas Pratique : Module EC2 Personnalisable

Pour démontrer la puissance de la personnalisation via les variables d'entrée, créons un module EC2 qui permet aux utilisateurs de spécifier le type d'instance et le subnet sans modifier le code du module.

#### Étape 1 : Restriction des Types

Par défaut, une variable Terraform peut accepter n'importe quel type de valeur (string, number, boolean, object, list). Pour éviter les erreurs, nous allons **restreindre les types** que nos variables peuvent accepter.

```hcl
variable "instance_type" {
  description = "Type d'instance EC2 à lancer"
  type        = string  # Restriction : uniquement des chaînes
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "L'ID du Subnet où lancer l'instance"
  type        = string  # Restriction : uniquement des chaînes
}
```

**Avantage** : Si un utilisateur passe une valeur du mauvais type, Terraform affichera une erreur **immédiatement**, avant même de planifier les changements.

#### Étape 2 : Validation de Format avec Regex

AWS attend des formats spécifiques pour certaines ressources. Par exemple, un Subnet ID doit correspondre au format `subnet-xxxxxxxxx`. Nous pouvons valider cela avec une expression régulière.

```hcl
variable "subnet_id" {
  description = "L'ID du Subnet où lancer l'instance"
  type        = string
  
  validation {
    condition     = length(regexall("^subnet-[\\d|\\w]+$", var.subnet_id)) == 1
    error_message = "Le subnet_id doit correspondre au format AWS ^subnet-[\\d|\\w]+$"
  }
}
```

**Explication de la validation :**
- `regexall()` : Cherche toutes les correspondances du pattern dans la chaîne
- `^subnet-[\\d|\\w]+$` : Pattern qui valide le format AWS
  - `^` : Début de la chaîne
  - `subnet-` : Préfixe obligatoire
  - `[\\d|\\w]+` : Un ou plusieurs chiffres ou lettres
  - `$` : Fin de la chaîne
- `length(...) == 1` : S'assure qu'il y a exactement une correspondance

#### Étape 3 : Validation de Liste de Valeurs

Pour le type d'instance, nous voulons restreindre les choix à une liste prédéfinie pour éviter des configurations coûteuses par erreur.

```hcl
variable "instance_type" {
  description = "Type d'instance EC2 à lancer"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = contains(["t2.micro", "t2.small", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Le type d'instance doit être l'un des suivants : t2.micro, t2.small, t3.micro, t3.small, t3.medium."
  }
}
```

**Avantage** : Empêche les utilisateurs de lancer accidentellement des instances très coûteuses (ex: `m5.24xlarge`).

#### Étape 4 : Utilisation dans le Module

Une fois les variables définies et validées, elles peuvent être utilisées dans les ressources :

```hcl
resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type  # Variable validée
  subnet_id     = var.subnet_id      # Variable validée avec format AWS
  
  tags = {
    Name = var.instance_name
  }
}
```

#### Étape 5 : Personnalisation lors de l'Utilisation

Les utilisateurs peuvent maintenant personnaliser le comportement du module **sans le modifier** :

```hcl
module "ec2_web" {
  source = "./modules/ec2"
  
  # Personnalisation du comportement
  instance_type    = "t3.micro"                      # Type validé
  subnet_id        = module.vpc.public_subnet_ids[0] # Format validé
  vpc_id           = module.vpc.vpc_id
  instance_name    = "terraform-web-server"
  enable_public_ip = true
}
```

**Résultat :**
- Module réutilisable pour différents cas d'usage
- Validation garantit la conformité avec AWS
- Erreurs détectées avant l'exécution
- Code du module non modifié

### Variables avec Valeurs par Défaut

Les valeurs par défaut rendent les variables **optionnelles** et facilitent l'utilisation.

```hcl
variable "instance_type" {
  description = "Type d'instance EC2 à lancer"
  type        = string
  default     = "t3.micro"  # Valeur par défaut économique
}
```

**Utilisation :**
```hcl
# Sans override : utilise t3.micro
module "ec2" {
  source = "./modules/ec2"
}

# Avec override : utilise t3.large
module "ec2" {
  source        = "./modules/ec2"
  instance_type = "t3.large"
}
```

### Variables Booléennes pour Activer/Désactiver des Fonctionnalités

```hcl
variable "enable_dns_hostnames" {
  description = "Activer les DNS hostnames dans le VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Activer le support DNS dans le VPC"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Activer le NAT Gateway pour les subnets privés"
  type        = bool
  default     = true
}
```

**Utilisation dans les ressources :**
```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = local.common_tags
}
```

### Variables pour l'Optimisation des Coûts

```hcl
variable "single_nat_gateway" {
  description = "Utiliser un seul NAT Gateway pour tous les subnets privés (optimisation des coûts)"
  type        = bool
  default     = false
}
```

**Impact financier :**
- `single_nat_gateway = false` : 1 NAT Gateway par AZ → **Haute disponibilité** mais plus coûteux
- `single_nat_gateway = true` : 1 NAT Gateway partagé → **Économique** mais point unique de défaillance

### Variables pour le Comportement Réseau

```hcl
variable "map_public_ip_on_launch" {
  description = "Auto-assigner une IP publique au lancement des instances dans les subnets publics"
  type        = bool
  default     = true
}
```

---

## Exemple Complet : Module VPC Sécurisé et Personnalisable

### Fichier `variables.tf` Complet

```hcl
# ===== Variables avec Validation =====

variable "vpc_cidr" {
  description = "CIDR block du VPC"
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
  description = "Liste des zones de disponibilité pour les subnets publics"
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

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être l'un des suivants : dev, staging, prod."
  }
}

variable "project_name" {
  description = "Nom du projet"
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

# ===== Variables de Personnalisation =====

variable "enable_dns_hostnames" {
  description = "Activer les DNS hostnames dans le VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Activer le support DNS dans le VPC"
  type        = bool
  default     = true
}

variable "map_public_ip_on_launch" {
  description = "Auto-assigner une IP publique au lancement pour les subnets publics"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Activer le NAT Gateway pour les subnets privés"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Utiliser un seul NAT Gateway pour tous les subnets privés (optimisation des coûts)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags additionnels à appliquer à toutes les ressources"
  type        = map(string)
  default     = {}
}
```

### Utilisation du Module

#### Exemple 1 : Configuration de Développement (par défaut)

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  # Utilise les valeurs par défaut
  # - vpc_cidr = "10.0.0.0/16"
  # - environment = "dev"
  # - enable_nat_gateway = true
  # - single_nat_gateway = false (HA)
}
```

#### Exemple 2 : Configuration de Production Personnalisée

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr     = "172.16.0.0/16"
  public_azs   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_azs  = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  environment  = "prod"
  project_name = "mon-app-production"
  
  # Haute disponibilité
  enable_nat_gateway = true
  single_nat_gateway = false  # Un NAT Gateway par AZ
  
  # Configuration réseau
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true
  
  tags = {
    Owner      = "DevOps Team"
    CostCenter = "IT-PROD-001"
    Backup     = "daily"
  }
}
```

#### Exemple 3 : Configuration Économique

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  environment  = "dev"
  project_name = "test-app"
  
  # Optimisation des coûts
  enable_nat_gateway = true
  single_nat_gateway = true  # Un seul NAT Gateway
  
  # Minimal
  public_azs  = ["us-east-1a"]
  private_azs = ["us-east-1a"]
}
```

---

## Exemples d'Erreurs de Validation

### Erreur 1 : CIDR Invalide

```bash
$ terraform plan

Error: Invalid value for variable

  on main.tf line 5:
   5:   vpc_cidr = "10.0.0.0/8"

Le masque CIDR doit être entre /16 et /28.
```

### Erreur 2 : Environnement Non Autorisé

```bash
$ terraform plan

Error: Invalid value for variable

  on main.tf line 8:
   8:   environment = "test"

L'environnement doit être l'un des suivants : dev, staging, prod.
```

### Erreur 3 : Format de Zone de Disponibilité

```bash
$ terraform plan

Error: Invalid value for variable

  on main.tf line 10:
  10:   public_azs = ["us-east-1", "us-west-2"]

Chaque zone de disponibilité doit correspondre au format AWS (ex: us-east-1a).
```

### Erreur 4 : Nom de Projet Invalide

```bash
$ terraform plan

Error: Invalid value for variable

  on main.tf line 12:
  12:   project_name = "Mon Projet 2024"

Le nom du projet doit contenir uniquement des lettres minuscules, chiffres, tirets et underscores.
```

---

## Types de Validations Disponibles

### 1. Validation de Longueur

```hcl
validation {
  condition     = length(var.name) <= 125
  error_message = "Le nom ne peut pas dépasser 125 caractères."
}
```

### 2. Validation de Plage (Range)

```hcl
validation {
  condition     = var.port >= 1 && var.port <= 65535
  error_message = "Le port doit être entre 1 et 65535."
}
```

### 3. Validation avec Regex

```hcl
validation {
  condition     = can(regex("^[a-z0-9-]+$", var.name))
  error_message = "Le nom doit contenir uniquement des minuscules, chiffres et tirets."
}
```

### 4. Validation de Type (Entier)

```hcl
validation {
  condition     = can(parseint(tostring(var.number), 10))
  error_message = "La valeur doit être un entier."
}
```

### 5. Validation avec Liste Autorisée

```hcl
validation {
  condition     = contains(["small", "medium", "large"], var.size)
  error_message = "La taille doit être : small, medium ou large."
}
```

### 6. Validation de Liste (tous les éléments)

```hcl
validation {
  condition     = alltrue([for item in var.list : length(item) > 0])
  error_message = "Tous les éléments de la liste doivent être non vides."
}
```

---

## Bonnes Pratiques

### 1. Validations Complètes

**À faire** : Valider le format ET la plage
```hcl
variable "vpc_cidr" {
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "Format CIDR invalide."
  }
  
  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16
    error_message = "Le masque doit être au minimum /16."
  }
}
```

### 2. Messages d'Erreur Descriptifs

**À faire** : Messages clairs et actionnables
```hcl
error_message = "L'environnement doit être l'un des suivants : dev, staging, prod."
```

**À éviter** : Messages vagues
```hcl
error_message = "Valeur invalide."
```

### 3. Valeurs par Défaut Sensées

**À faire** : Des défauts sûrs et économiques
```hcl
variable "instance_type" {
  default = "t3.micro"  # Économique pour dev/test
}
```

### 4. Validation Précoce

**À faire** : Valider dès que possible
- Évite les erreurs tardives
- Économise du temps
- Améliore l'expérience utilisateur

### 5. Documentation

**À faire** : Documenter les validations
```hcl
variable "vpc_cidr" {
  description = "CIDR block du VPC. Doit être entre /16 et /28 pour respecter les bonnes pratiques AWS."
  # ...validations...
}
```

---

## Nouveautés Terraform 1.9+

### Validations Croisées (Cross-Variable Validation)

Avant Terraform 1.9, les validations ne pouvaient accéder qu'aux attributs de la variable elle-même.

**Depuis Terraform 1.9**, la `condition` peut utiliser d'autres variables :

```hcl
variable "enable_nat_gateway" {
  type = bool
}

variable "private_azs" {
  type = list(string)
  
  validation {
    # Peut maintenant utiliser une autre variable !
    condition     = !var.enable_nat_gateway || length(var.private_azs) > 0
    error_message = "Si enable_nat_gateway est activé, private_azs ne peut pas être vide."
  }
}
```

**Limitation** : L'expression doit **toujours inclure** la variable testée.

---

## Résumé

### Ce que nous avons appris

1. **Validation des Inputs**
   - Bloc `validation` avec `condition` et `error_message`
   - Validations multiples sur une même variable
   - Types de validation : longueur, regex, plage, format
   - Validation de listes avec `alltrue()`

2. **Personnalisation du Comportement**
   - Variables avec valeurs par défaut
   - Variables booléennes pour activer/désactiver
   - Variables pour l'optimisation des coûts
   - Flexibilité sans modification du code

3. **Bonnes Pratiques**
   - Messages d'erreur descriptifs
   - Validations complètes
   - Documentation claire
   - Valeurs par défaut sensées

### Avantages des Modules Validés et Personnalisables

- **Détection précoce** des erreurs
- **Meilleure expérience** utilisateur
- **Débogage facilité**
- **Réutilisabilité** maximale
- **Sécurité** renforcée
- **Flexibilité** conservée

---

## Implémentation dans le Challenge

Les modifications ont été appliquées à l'infrastructure du **Jour 2** :

**Module VPC (enrichi) :**
- `jour2/modules/vpc/variables.tf` : Ajout de toutes les validations et nouvelles variables
- `jour2/modules/vpc/main.tf` : Utilisation des nouvelles variables de personnalisation

**Module EC2 (nouveau) :**
- `jour2/modules/ec2/variables.tf` : Variables avec validation de type et format (subnet_id, instance_type)
- `jour2/modules/ec2/main.tf` : Instance EC2 avec Security Group
- `jour2/modules/ec2/outputs.tf` : Outputs de l'instance (IPs, ID, ARN)

**Fichier principal :**
- `jour2/main.tf` : Utilisation des deux modules avec communication VPC → EC2

**Testez le module avec des valeurs invalides pour voir les validations en action !**

**Exemples de tests :**
```bash
# Test avec un subnet_id invalide
module "ec2_web" {
  subnet_id = "invalid-subnet"  # Erreur : format invalide
}

# Test avec un instance_type non autorisé
module "ec2_web" {
  instance_type = "m5.24xlarge"  # Erreur : type non dans la liste
}
```

---

## Prochaines Étapes

Dans le **Jour 6**, nous explorerons :
- **Data Sources** : Récupérer des données AWS existantes
- Différence entre `resource` et `data`
- Utilisation pratique avec notre module VPC

---

<div align="center">

**[⬅️ Jour 4](../jour4/README.md) | [Accueil](../README.md) | [Jour 6 ➡️](../jour6/README.md)**

*Challenge 30 jours Terraform - Jour 5/30*

</div>

