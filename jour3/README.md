# Jour 3 - Continuation de l'infrastructure VPC

## Vue d'ensemble

Ce jour 3 continue l'infrastructure VPC commencée dans le jour 2, en se concentrant sur les expressions et fonctions Terraform avancées.

## Améliorations apportées au VPC

### 1. Système de tags dynamiques

**Problème résolu :** Les ressources avaient des tags fixes (Name et Environment).

**Solution implémentée :**
- Ajout d'une variable `tags` de type `map(string)` pour permettre des tags personnalisés
- Utilisation de la fonction `merge()` pour fusionner les tags par défaut avec les tags personnalisés
- Les tags personnalisés peuvent écraser les tags par défaut

**Code exemple :**
```hcl
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Dans les ressources
tags = merge({
  Name        = var.project_name
  Environment = var.environment
}, var.tags, {
  Name = "${var.project_name}-igw"
})
```

### 2. NAT Gateway avec expressions conditionnelles

**Fonctionnalité ajoutée :** NAT Gateway pour permettre aux subnets privés d'accéder à Internet.

**Variables ajoutées :**
- `enable_nat_gateway` : Active/désactive le NAT Gateway
- `single_nat_gateway` : Optimisation des coûts (1 NAT Gateway pour tous les subnets privés)

**Expressions utilisées :**
```hcl
# Calcul conditionnel du nombre de NAT Gateways
count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0

# Sélection conditionnelle du subnet
subnet_id = var.single_nat_gateway ? aws_subnet.public[0].id : aws_subnet.public[count.index].id
```

### 3. Routes dynamiques avec blocs conditionnels

**Fonctionnalité :** Ajout de routes vers le NAT Gateway seulement si activé.

**Code implémenté :**
```hcl
dynamic "route" {
  for_each = var.enable_nat_gateway ? [1] : []
  content {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }
}
```

## Concepts Terraform explorés

### Expressions et Fonctions
- **Fonction `merge()`** : Fusion de maps de tags
- **Expressions conditionnelles ternaires** : `condition ? true_value : false_value`
- **Fonction `length()`** : Calcul du nombre d'éléments dans une liste
- **Blocs `dynamic`** : Création conditionnelle de blocs de configuration

### Gestion des ressources
- **Création conditionnelle** avec `count` et expressions
- **Tags dynamiques** avec fusion de maps
- **Dépendances** entre ressources (NAT Gateway dépend d'Internet Gateway)

### Optimisations
- **Option de coût** : Un seul NAT Gateway pour tous les subnets privés
- **Haute disponibilité** : Un NAT Gateway par AZ
- **Flexibilité** : Activation/désactivation du NAT Gateway

## Structure finale

Le VPC comprend maintenant :
- VPC principal avec DNS activé
- Internet Gateway
- Subnets publics (2 AZs)
- Subnets privés (2 AZs)
- Route tables (publique et privée)
- NAT Gateway (conditionnel)
- Elastic IPs pour NAT Gateway
- Routes dynamiques vers NAT Gateway

## Utilisation

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"
  public_azs = ["us-east-1a", "us-east-1b"]
  private_azs = ["us-east-1a", "us-east-1b"]
  environment = "dev"
  project_name = "terraform_challenge"
  
  # Configuration NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = false
  
  # Tags personnalisés
  tags = {
    Owner       = "DevOps Team"
    CostCenter  = "IT-001"
    Backup      = "daily"
    Monitoring  = "enabled"
  }
}
```
