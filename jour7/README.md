# Data Sources et External Data Sources

## Introduction

Jusqu'à présent, nous avons appris à maîtriser les expressions, les fonctions, et la création de ressources avec Terraform. Nous savons comment construire des modules flexibles et adaptables grâce aux variables d'entrée et aux expressions conditionnelles.

Mais Terraform ne se contente pas seulement de créer de nouvelles ressources. Il offre une autre classe d'objets puissante appelée **Data Sources** qui permet de récupérer des informations depuis l'extérieur de Terraform.

Contrairement aux ressources qui génèrent quelque chose de nouveau dans votre infrastructure, les Data Sources récupèrent des données existantes sans rien créer. Elles sont comme des "lecteurs d'informations" qui vous permettent d'accéder à des données déjà présentes dans votre environnement AWS, dans des APIs externes, ou même dans des fichiers locaux.

Elles possèdent des types, des identifiants, des arguments et des attributs, tout comme les ressources. La principale différence réside dans le fait qu'elles ne créent ni ne modifient rien ; elles utilisent leurs arguments pour rechercher et filtrer les données de leur fournisseur et les rendre accessibles au reste du programme.

## Différence entre Ressource et Data Source

### Ressource (Resource)
- **Crée, modifie ou supprime** quelque chose dans votre infrastructure
- **Commande** : `resource "aws_vpc" "main"`
- **Action** : Terraform va créer un nouveau VPC dans AWS
- **État** : Terraform track l'état de cette ressource dans le state file

### Data Source
- **Lit seulement** des informations existantes
- **Commande** : `data "aws_vpc" "existing"`
- **Action** : Terraform va chercher un VPC qui existe déjà dans AWS
- **État** : Terraform ne track pas l'état, juste récupère les infos

**La différence clé** : Ressource = "Je veux créer quelque chose de nouveau", Data Source = "Je veux utiliser quelque chose qui existe déjà"

## Exemple avec le module EC2

```hcl
# Data source pour récupérer l'AMI Ubuntu la plus récente si non spécifiée
data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical (propriétaire des AMI Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Instance EC2
resource "aws_instance" "main" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  # ... autres attributs
}
```

La data source `aws_ami` récupère automatiquement la dernière version d'Ubuntu 22.04 disponible tandis que l'expression ternaire permet à l'utilisateur de choisir entre une AMI spécifique ou la récupération automatique.

## Data Source avec Filtres pour AWS AMI

La data source `aws_ami` utilise des filtres pour affiner la recherche parmi les milliers d'AMI disponibles sur AWS. Voici comment nous configurons ces filtres pour récupérer automatiquement la dernière version d'Ubuntu :

```hcl
data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical (propriétaire des AMI Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

Ce bloc filter supplémentaire peut être utilisé pour filtrer un groupe plus large de ressources. Nous combinons cela avec quelques arguments standards pour nous assurer d'obtenir la dernière AMI Ubuntu directement de l'entreprise qui fabrique Ubuntu.

Une chose que vous pourriez vous demander est : que se passe-t-il quand une data source ne peut pas trouver une ressource correspondante ? Dans ce cas, cela dépend beaucoup de la data source spécifique. Pour la plupart des data sources, comme la data source `aws_ami`, l'échec de trouver une correspondance lancera une erreur et empêchera le plan de continuer. Il y a d'autres ressources qui permettent l'échec. En général, les data sources qui recherchent un nombre dynamique de ressources pourront retourner zéro résultat. La data source `aws_subnets` que nous utilisons en est un exemple, car l'attribut ID peut être une liste vide si aucun subnet n'est configuré.

## Autres Types de Data Sources

### Data Sources AWS courantes

```hcl
# Récupérer les zones de disponibilité
data "aws_availability_zones" "available" {
  state = "available"
}

# Récupérer un VPC existant
data "aws_vpc" "existing" {
  tags = {
    Name = "production-vpc"
  }
}

# Récupérer les subnets d'un VPC
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}
```

### External Data Sources

Les External Data Sources permettent d'intégrer des données provenant de sources externes à Terraform, comme des scripts locaux, des APIs REST, ou des fichiers. Contrairement aux data sources AWS qui récupèrent des informations depuis votre infrastructure cloud, les external data sources vous permettent d'exécuter des programmes externes et de récupérer leur sortie sous forme de données utilisables dans votre configuration Terraform.

```hcl
# Exécuter un script et récupérer le résultat
data "external" "user_info" {
  program = ["bash", "get-user-info.sh"]
}

# Récupérer des données depuis une API
data "http" "latest_version" {
  url = "https://api.github.com/repos/terraform-aws-modules/terraform-aws-vpc/releases/latest"
}
```

Ces data sources sont particulièrement utiles pour récupérer des informations dynamiques qui ne sont pas disponibles dans les providers Terraform standard, comme des versions de logiciels depuis des APIs, des configurations depuis des fichiers locaux, ou des métadonnées depuis des scripts personnalisés.

### Data Sources pour la sécurité

```hcl
# Récupérer des paramètres SSM
data "aws_ssm_parameter" "database_password" {
  name = "/myapp/database/password"
}

# Récupérer des secrets
data "aws_secretsmanager_secret" "api_key" {
  name = "myapp-api-key"
}
```

## Avantages des Data Sources

Les Data Sources transforment vos modules de composants statiques en éléments intelligents qui s'adaptent automatiquement à l'évolution de votre infrastructure. Elles éliminent la maintenance manuelle des identifiants, garantissent l'utilisation des versions les plus récentes, et offrent une flexibilité totale pour l'intégration avec des ressources existantes.

Cette capacité de "lire" plutôt que de "créer" ouvre de nouvelles possibilités pour rendre vos modules encore plus intelligents et adaptatifs, en s'appuyant sur l'état réel de votre infrastructure existante.

## Conclusion

Les Data Sources représentent un pas important dans la maîtrise de Terraform. Elles permettent de créer des modules qui s'adaptent automatiquement à l'environnement existant, réduisant la maintenance manuelle et améliorant la flexibilité de vos configurations.

En combinant les Data Sources avec les expressions et fonctions que nous avons vues précédemment, nous créons des modules véritablement intelligents qui peuvent s'adapter à différents environnements et évoluer avec votre infrastructure.
