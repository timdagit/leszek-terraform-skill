output "environment" {
  value = var.environment

  precondition {
    condition     = contains(local.environments, var.environment)
    error_message = "Environment '${var.environment}' is not listed in global.environments (${join(", ", local.environments)})."
  }
}

output "global" {
  value = local.merged.global
}

output "tfbackend" {
  value = local.merged.tfbackend
}

output "layer" {
  value = local.merged.layer
}
