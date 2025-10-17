output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.main.id
}

output "instance_public_ip" {
  description = "Adresse IP publique de l'instance"
  value       = aws_instance.main.public_ip
}

output "instance_private_ip" {
  description = "Adresse IP privée de l'instance"
  value       = aws_instance.main.private_ip
}

output "security_group_id" {
  description = "ID du security group attaché à l'instance"
  value       = aws_security_group.ec2_sg.id
}

output "instance_arn" {
  description = "ARN de l'instance EC2"
  value       = aws_instance.main.arn
}

output "ami_used" {
  description = "ID de l'AMI utilisée"
  value       = aws_instance.main.ami
}

output "iam_role_name" {
  description = "Nom du rôle IAM attaché à l'instance (vide si désactivé)"
  value       = var.enable_iam_role ? aws_iam_role.instance_role[0].name : ""
}

output "iam_role_arn" {
  description = "ARN du rôle IAM attaché à l'instance (vide si désactivé)"
  value       = var.enable_iam_role ? aws_iam_role.instance_role[0].arn : ""
}

output "iam_role" {
  description = "Objet complet du rôle IAM pour permettre l'attachement de politiques personnalisées"
  value       = var.enable_iam_role ? aws_iam_role.instance_role[0] : null
}

