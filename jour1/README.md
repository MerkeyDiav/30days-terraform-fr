Jour 1 – Introduction à Terraform

Bienvenue dans le Jour 1 de notre challenge 30 jours pour apprendre Terraform en français.
Aujourd’hui, nous posons les bases et explorons les concepts fondamentaux de Terraform et de l’Infrastructure as Code (IaC).

Objectifs du jour

Comprendre ce qu’est Terraform et pourquoi il est utilisé.

Découvrir le langage HCL (HashiCorp Configuration Language).

Comprendre les concepts de provider, state, backend, et workspaces.

Se familiariser avec le workflow Terraform : init → plan → apply.

1. Pourquoi Terraform ?

Créer et gérer des infrastructures cloud à la main peut être complexe et chronophage.
Par exemple, j’ai dû créer un VPC sur AWS entièrement à la main, et même avec de l’expérience, cela m’a pris des heures pour configurer correctement toutes les ressources et suivre les bonnes pratiques.

La découverte de Terraform a été une révélation :

Terraform permet de décrire l’infrastructure avec du code.

Le moteur Terraform se charge ensuite de créer, modifier ou supprimer automatiquement les ressources.

Une tâche qui prenait des heures peut maintenant être réalisée en quelques minutes.

2. Comprendre l’IaC et Terraform

L’Infrastructure as Code (IaC) est une approche permettant de provisionner des infrastructures à l’aide de pratiques de codage.

Quelques points importants :

Terraform n’est pas le seul outil IaC : Pulumi, AWS CloudFormation, ou GCP Deployment Manager existent aussi.

Terraform est multi-cloud et déclaratif, ce qui le rend plus simple et flexible.

L’infrastructure peut être versionnée avec Git, analysée pour la qualité et la sécurité, et intégrée dans des pipelines CI/CD.

3. Concepts fondamentaux de Terraform

HCL (HashiCorp Configuration Language) : un langage déclaratif et lisible, proche de l’anglais, permettant de définir l’état final souhaité de l’infrastructure.

Provider (Fournisseur) : plugin qui permet à Terraform de communiquer avec des services externes comme AWS, Azure, Google Cloud, Docker ou GitHub.

State (État) : fichier terraform.tfstate qui stocke la photographie actuelle de l’infrastructure.

Backend : emplacement où l’état est stocké, local ou distant (ex : AWS S3, Azure Blob Storage).

Workspaces : permettent de gérer plusieurs environnements (dev, test, prod) avec des états séparés.

4. Le workflow Terraform en pratique

Le cycle de déploiement Terraform suit toujours ces étapes :

Changement souhaité : ajouter, modifier ou supprimer une ressource.

terraform init : initialise le projet, télécharge les providers et configure le backend.

terraform plan : compare l’état actuel avec le code et génère un plan d’action.

terraform apply : applique le plan en créant, modifiant ou supprimant les ressources.

Ce flux garantit que l’infrastructure correspond exactement à ce qui est défini dans le code.

5. Ce que vous allez apprendre dans la prochaine partie

Dans le Jour 2, nous entrerons dans la pratique en créant notre premier fichier Terraform et en configurant un provider AWS.

Bibliographie & Ressources

Documentation Terraform – AWS Provider

Brikman, Y. (2023). Terraform: Up and Running, 3rd Edition. O’Reilly Media.

McKendrick, R. (2021). Infrastructure as Code for Beginners. Packt Publishing.