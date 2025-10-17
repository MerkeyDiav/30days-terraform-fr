# Expressions et Fonctions Terraform

## Introduction

Les expressions et fonctions Terraform permettent de créer des configurations dynamiques et flexibles. Au lieu de dupliquer du code ou de créer des ressources statiques, nous pouvons utiliser des expressions conditionnelles et des fonctions intégrées pour rendre notre infrastructure adaptable selon les besoins.

Dans notre module EC2, nous avons enrichi les fonctionnalités en ajoutant le support IAM. Cette implémentation illustre parfaitement l'utilisation des expressions et fonctions pour créer un module intelligent capable de s'adapter aux différents cas d'usage.

## Les Expressions Conditionnelles (Ternaires)

L'expression ternaire suit la syntaxe `condition ? valeur_si_vrai : valeur_si_faux`. Elle permet de prendre des décisions directement dans les attributs de ressources.

### Création Conditionnelle avec Count

Dans notre module, nous utilisons l'expression ternaire avec le meta-argument `count` pour créer des ressources de manière conditionnelle.

```hcl
data "aws_iam_policy_document" "instance_assume_role_policy" {
  count = var.enable_iam_role ? 1 : 0
  # ...
}
```

Si `enable_iam_role` est vrai, la ressource est créée. Sinon, elle n'existe pas. Cette technique permet d'activer ou désactiver des fonctionnalités entières sans dupliquer de code.

### Nommage Dynamique

L'expression ternaire permet également de générer des noms dynamiques selon que l'utilisateur fournit un nom personnalisé ou non.

```hcl
resource "aws_iam_role" "instance_role" {
  count = var.enable_iam_role ? 1 : 0
  name  = var.iam_role_name != "" ? var.iam_role_name : "${var.instance_name}-role"
}
```

Cette ligne vérifie si un nom personnalisé est fourni. Si oui, on l'utilise. Sinon, on génère automatiquement un nom basé sur le nom de l'instance.

### Gestion de null vs Valeurs Vides

Dans la ressource EC2, nous utilisons `null` pour indiquer qu'un attribut ne doit pas être défini.

```hcl
resource "aws_instance" "main" {
  iam_instance_profile = var.enable_iam_role ? aws_iam_instance_profile.instance_profile[0].name : null
}
```

La différence entre `null` et une chaîne vide est importante. `null` signifie "ne pas définir cet attribut", tandis que `""` signifie "définir l'attribut avec une valeur vide". AWS attend `null` pour les attributs optionnels non utilisés.

### Outputs Conditionnels

Les outputs utilisent également des expressions ternaires pour gérer les cas où les ressources n'existent pas.

```hcl
output "iam_role_name" {
  value = var.enable_iam_role ? aws_iam_role.instance_role[0].name : ""
}
```

Notez l'utilisation de `[0]` pour accéder à la ressource. Quand on utilise `count`, Terraform transforme la ressource en liste. Même avec `count = 1`, il faut accéder au premier élément via l'index 0.

## Les Fonctions Terraform

### La Fonction merge()

La fonction `merge()` fusionne plusieurs maps en une seule. Si plusieurs maps contiennent la même clé, la valeur de la dernière map prend le dessus.

```hcl
resource "aws_iam_role" "instance_role" {
  tags = merge(var.tags, {
    Name = var.iam_role_name != "" ? var.iam_role_name : "${var.instance_name}-role"
  })
}
```

Cette fonction permet de créer une hiérarchie de tags. Les tags personnalisés de l'utilisateur sont combinés avec des tags spécifiques à chaque ressource. Si l'utilisateur a défini un tag `Name`, il sera écrasé par notre valeur. Sinon, il est simplement ajouté.

### Interpolation de Chaînes

Terraform permet d'insérer des variables dans des chaînes avec la syntaxe `${}`.

```hcl
name = "${var.instance_name}-role"
description = "Security group pour l'instance EC2 ${var.instance_name}"
```

Cette syntaxe combine du texte statique avec des valeurs dynamiques. Pour une chaîne contenant uniquement une variable, les accolades peuvent être omises, mais dès qu'on combine plusieurs éléments, elles deviennent nécessaires.

### Les Fonctions startswith() et length()

Pour nos validations de variables, nous utilisons `startswith()` et `length()` plutôt que des expressions régulières.

```hcl
validation {
  condition     = startswith(var.subnet_id, "subnet-") && length(var.subnet_id) > 7
  error_message = "Le subnet_id doit commencer par 'subnet-' et avoir une longueur suffisante."
}
```

Cette approche est plus claire que l'équivalent regex `length(regexall("^subnet-[\\d|\\w]+$", var.subnet_id)) == 1`. Pas besoin d'échapper les caractères spéciaux, et le code se lit naturellement.

## La Data Source aws_iam_policy_document

Cette data source est un outil spécialisé pour construire des politiques IAM conformes aux standards AWS.

```hcl
data "aws_iam_policy_document" "instance_assume_role_policy" {
  count = var.enable_iam_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
```

Le résultat est accessible via `.json` et contient le document JSON complet prêt à être utilisé.

```hcl
resource "aws_iam_role" "instance_role" {
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy[0].json
}
```

Cette approche est préférable à `jsonencode()` car elle valide que la structure correspond aux exigences AWS et offre une meilleure expérience de développement.

## Le Meta-Argument count

Le meta-argument `count` transforme la façon dont Terraform gère les ressources. Normalement, chaque block de ressource crée exactement une ressource. Avec `count`, on peut créer zéro, une, ou plusieurs copies.

```hcl
resource "aws_iam_role" "instance_role" {
  count = var.enable_iam_role ? 1 : 0
}
```

Quand `count` est utilisé, la ressource devient une liste. Chaque instance a un index accessible via `count.index` pendant la création. Après la création, on accède aux instances via des index comme `[0]`, `[1]`, etc.

Notre pattern `count = condition ? 1 : 0` est un idiome courant pour la création conditionnelle. C'est différent de l'utilisation classique de `count` pour créer plusieurs copies identiques. Par exemple, `count = 3` créerait trois instances EC2 identiques.

## Opérateurs Logiques

Terraform supporte les opérateurs de comparaison et logiques standards.

Opérateurs de comparaison :
- `==` égal
- `!=` différent
- `<` inférieur
- `>` supérieur
- `<=` inférieur ou égal
- `>=` supérieur ou égal

Opérateurs logiques :
- `&&` ET logique
- `||` OU logique
- `!` NON logique

Exemple d'utilisation combinée :

```hcl
condition = var.ami_id == "" || (startswith(var.ami_id, "ami-") && length(var.ami_id) > 4)
```

Cette expression se lit : "soit ami_id est vide, soit il commence par 'ami-' ET a une longueur suffisante".

## Références entre Ressources

Quand nous référençons une ressource dans une autre, Terraform crée automatiquement une dépendance implicite.

```hcl
resource "aws_iam_instance_profile" "instance_profile" {
  name = aws_iam_role.instance_role[0].name
  role = aws_iam_role.instance_role[0].name
}
```

Terraform comprend que l'instance profile dépend du rôle IAM et ordonnera automatiquement les opérations de création. Ce graphe de dépendances permet de décrire l'état souhaité sans se préoccuper de l'ordre d'exécution.

## Intérêt dans Notre Infrastructure

L'utilisation des expressions et fonctions dans notre module EC2 apporte plusieurs bénéfices concrets.

Premièrement, la flexibilité. Les utilisateurs peuvent activer ou désactiver le support IAM avec une simple variable booléenne. Pas besoin de créer deux versions du module ou de dupliquer du code.

Deuxièmement, la maintenabilité. Les expressions ternaires et les fonctions rendent le code plus compact et plus facile à comprendre. Au lieu de dizaines de lignes dupliquées, une seule ligne expressive suffit.

Troisièmement, l'expérience utilisateur. Les validations avec `startswith()` et `length()` produisent des messages d'erreur clairs et compréhensibles. L'utilisateur sait exactement ce qui ne va pas.

Quatrièmement, la puissance. En combinant expressions et fonctions, nous créons un module capable de s'adapter à des dizaines de scénarios différents sans modification du code source. Un utilisateur peut fournir son propre nom de rôle, ou laisser le module le générer. Il peut activer IAM ou non. Tout cela avec les mêmes ressources.

Cinquièmement, la robustesse. Les validations empêchent les erreurs avant même l'exécution de Terraform. Si un identifiant AWS est mal formaté, l'utilisateur le sait immédiatement au moment de la validation du plan.

## Conclusion

Les expressions et fonctions transforment Terraform d'un simple outil déclaratif en un véritable langage de configuration programmable. Notre module EC2 démontre comment quelques expressions bien placées peuvent créer une flexibilité énorme sans compromettre la simplicité.

Le pattern `count = condition ? 1 : 0` pour la création conditionnelle, la fonction `merge()` pour la gestion des tags, les expressions ternaires pour le nommage dynamique, et les fonctions de validation comme `startswith()` forment ensemble une boîte à outils puissante pour créer des modules réutilisables et adaptables.

En maîtrisant ces concepts, nous pouvons créer des infrastructures qui s'adaptent aux besoins plutôt que de forcer les besoins à s'adapter à l'infrastructure.

