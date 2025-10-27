# Templates et Fichiers : Rendre l'Infrastructure Configurable

## Introduction

Au cours de nos précédents chapitres, nous avons exploré les expressions conditionnelles et les fonctions Terraform pour créer des modules intelligents. Notre module EC2 peut désormais s'adapter dynamiquement selon les besoins : activer ou désactiver IAM, générer des noms automatiquement, valider des entrées avec des fonctions simples plutôt que des regex complexes.

Cependant, il arrive souvent que nous ayons besoin d'aller plus loin dans la personnalisation. Que faire si nous devons installer des agents de monitoring spécifiques sur nos instances ? Ou configurer des applications avec des paramètres différents selon l'environnement ? Ou encore générer des fichiers de configuration complexes ?

C'est là qu'interviennent les **templates et les fonctions de fichiers** de Terraform. Ces outils nous permettent de transformer des fichiers statiques en contenu dynamique, d'injecter des variables dans des scripts, et de générer des configurations sur mesure pour chaque déploiement.

## 1. La fonction file() : Charger des Fichiers Statiques

La fonction `file()` permet de charger le contenu d'un fichier externe directement dans Terraform. C'est idéal pour les scripts longs ou les configurations complexes.

```hcl
# Dans notre module EC2
resource "aws_instance" "main" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = var.enable_public_ip
  user_data = file("${path.module}/scripts/cloud-init.sh")
  
  # Attachement du profil IAM si activé
  iam_instance_profile        = var.enable_iam_role ? aws_iam_instance_profile.instance_profile[0].name : null

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}
```

`path.module` pointe vers le répertoire du module actuel. Le script `cloud-init.sh` sera chargé et exécuté au démarrage de l'instance. Cette approche évite d'avoir de longs scripts directement dans le code Terraform.

## 2. La fonction templatefile() : Templates Dynamiques

La fonction `templatefile()` va plus loin en permettant d'injecter des variables dans des fichiers templates. Contrairement à `file()` qui charge un contenu statique, `templatefile()` transforme le fichier en un véritable template où chaque variable peut être remplacée par des valeurs dynamiques calculées au moment de l'exécution. Cette approche permet de créer des configurations personnalisées pour chaque déploiement sans dupliquer de fichiers, tout en gardant la logique de configuration séparée du code Terraform principal.

```hcl
# Ajoutons une variable pour le script de monitoring
variable "enable_monitoring" {
  description = "Activer l'agent de monitoring CloudWatch"
  type        = bool
  default     = false
}

variable "monitoring_config" {
  description = "Configuration du monitoring"
  type        = object({
    log_group = string
    region    = string
  })
  default = {
    log_group = "/aws/ec2"
    region    = "us-east-1"
  }
}

# Utilisation dans la ressource EC2
resource "aws_instance" "main" {
  # ... autres attributs ...
  
  # Template dynamique avec variables
  user_data = templatefile("${path.module}/templates/cloud-init.tftpl", {
    instance_name    = var.instance_name
    enable_monitoring = var.enable_monitoring
    log_group        = var.monitoring_config.log_group
    region           = var.monitoring_config.region
    iam_role_arn     = var.enable_iam_role ? aws_iam_role.instance_role[0].arn : ""
  })
}
```

**Explication du fonctionnement du template :**

Le template `cloud-init.tftpl` utilise la syntaxe de templating de Terraform. Les variables sont injectées avec `${variable_name}` et les conditions avec `%{ if condition }`. Par exemple, `${instance_name}` sera remplacé par le nom réel de l'instance, et la section `%{ if enable_monitoring }` ne sera incluse que si le monitoring est activé.

Le fichier se termine par `.tftpl` (Terraform Template) pour indiquer qu'il s'agit d'un template Terraform, distinct d'un fichier statique. Cette convention aide à identifier rapidement les fichiers qui contiennent des variables à remplacer.

Quand Terraform exécute `templatefile()`, il lit le fichier `.tftpl`, remplace toutes les variables par leurs valeurs réelles, et génère un script bash final personnalisé pour chaque instance. C'est comme avoir un modèle de lettre où chaque destinataire reçoit sa version personnalisée.

## 3. Syntaxe des Templates : Logique et Itérations

Les templates Terraform supportent des structures de contrôle avancées.

```hcl
# Template pour un fichier de configuration d'application
resource "local_file" "app_config" {
  content = templatefile("${path.module}/templates/app-config.tftpl", {
    app_name     = var.instance_name
    environment  = var.environment
    databases    = var.databases
    features     = var.enabled_features
  })
  filename = "${path.module}/generated/app-config.json"
}
```

**Template `app-config.tftpl` :**
```json
{
  "application": {
    "name": "${app_name}",
    "environment": "${environment}",
    "features": {
%{ for feature in features }
      "${feature}": true,
%{ endfor }
    },
    "databases": [
%{ for db_name, db_config in databases }
      {
        "name": "${db_name}",
        "host": "${db_config.host}",
        "port": ${db_config.port}
      },
%{ endfor }
    ]
  }
}
```

Ce template génère un fichier JSON de configuration avec des boucles `%{ for }` pour itérer sur les listes et maps. La syntaxe permet de créer des configurations complexes à partir de variables structurées.

## 4. Quand ne PAS utiliser les Templates

Terraform offre des alternatives natives plus robustes pour certains formats. Au lieu de créer des templates JSON ou YAML manuellement, il est préférable d'utiliser les fonctions d'encodage intégrées qui garantissent la validité syntaxique et offrent une meilleure expérience de développement. Ces alternatives natives sont non seulement plus sûres, mais aussi plus maintenables car elles bénéficient de la validation automatique de Terraform.

**Dans l'exemple suivant, nous allons voir comment éviter les pièges courants des templates et privilégier les solutions natives de Terraform :**

```hcl
# ❌ Éviter : Template pour du JSON
# user_data = templatefile("${path.module}/templates/iam-policy.json.tftpl", {...})

# ✅ Préférer : Data source native
data "aws_iam_policy_document" "instance_policy" {
  statement {
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/*"]
  }
}

# ✅ Ou jsonencode() pour des objets simples
locals {
  config = {
    name        = var.instance_name
    environment = var.environment
    features    = var.enabled_features
  }
}

resource "aws_instance" "main" {
  # ... autres attributs ...
  user_data = jsonencode(local.config)
}
```

**Explication :** Pour JSON et YAML, utilisez `jsonencode()` et `yamlencode()`. Pour les politiques IAM, préférez `aws_iam_policy_document`. Les templates sont parfaits pour les scripts shell, les fichiers de configuration d'applications, ou tout format non supporté nativement par Terraform.

## Documentation et Bonnes Pratiques

### Structure des Fichiers

Notre module EC2 enrichi suit maintenant cette structure :

```
jour2/modules/ec2/
├── main.tf                    # Ressources principales
├── variables.tf               # Variables d'entrée
├── outputs.tf                 # Valeurs de sortie
├── README.md                  # Documentation du module
├── scripts/                   # Scripts statiques
│   └── cloud-init.sh         # Script de base
└── templates/                 # Templates dynamiques
    └── cloud-init.tftpl      # Template cloud-init
```

### Variables de Templates

| Variable | Type | Description | Valeur par défaut |
|----------|------|-------------|-------------------|
| `enable_monitoring` | `bool` | Active l'agent CloudWatch | `false` |
| `monitoring_config` | `object` | Configuration du monitoring | `{log_group="/aws/ec2", region="us-east-1"}` |
| `user_data_script` | `string` | Chemin vers script personnalisé | `""` |

### Utilisation des Templates

**Script statique :**
```hcl
module "ec2_simple" {
  source = "./modules/ec2"
  user_data_script = "./my-custom-script.sh"
}
```

**Template dynamique :**
```hcl
module "ec2_monitored" {
  source = "./modules/ec2"
  enable_monitoring = true
  monitoring_config = {
    log_group = "/aws/production"
    region    = "eu-west-1"
  }
}
```

### Bonnes Pratiques

1. **Utilisez `.tftpl`** pour les templates Terraform
2. **Préférez les fonctions natives** (`jsonencode()`, `aws_iam_policy_document`) pour JSON/YAML
3. **Gardez les templates simples** et bien documentés
4. **Testez vos templates** avec différentes valeurs de variables
5. **Séparez la logique** : templates pour scripts, fonctions natives pour données structurées

## Conclusion

Les templates et fonctions de fichiers transforment Terraform d'un simple outil de provisionnement en un générateur de configurations sophistiqué. Notre module EC2 peut désormais installer des agents de monitoring, configurer des applications, et s'adapter à des environnements complexes, le tout grâce à des fichiers templates maintenables et réutilisables.

La clé est de choisir le bon outil : `file()` pour du contenu statique, `templatefile()` pour du contenu dynamique, et les fonctions natives (`jsonencode()`, `aws_iam_policy_document`) pour les formats supportés.
