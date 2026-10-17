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

  # The state key has no environment in it, so each environment needs its own account or container.
  precondition {
    condition = length(distinct([
      for e in local.environments : "${try(local.raw.tfbackend[e].storage_acct, local.raw.tfbackend.storage_acct, "")}/${try(local.raw.tfbackend[e].container_name, local.raw.tfbackend.container_name, "")}"
    ])) == length(local.environments)
    error_message = "Each environment in global.environments needs its own tfbackend storage_acct or container_name, because the state key does not include the environment."
  }
}

output "layer" {
  value = local.merged.layer
}
