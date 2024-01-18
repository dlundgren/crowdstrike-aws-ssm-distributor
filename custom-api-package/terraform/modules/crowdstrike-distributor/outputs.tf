output "package_arn" {
  value = aws_ssm_document.distributor_package.arn
}

output "automation_arn" {
  value = aws_ssm_document.crowdstrike_falcon.arn
}