locals {
  config_file  = coalesce(var.config_file, "${path.root}/../../config/main.config.yml")
  raw          = yamldecode(file(local.config_file))
  environments = local.raw.global.environments

  # Layer directory 02-vnet reads layers.vnet in the config file.
  layer_name = replace(basename(abspath(path.root)), "/^[0-9]+-/", "")

  blocks = {
    global    = local.raw.global
    tfbackend = try(local.raw.tfbackend, {})
    layer     = try(local.raw.layers[local.layer_name], {})
  }

  # Plain settings, with the keys for the current environment merged over the top.
  # Keys named after an environment are dropped from the result.
  merged = {
    for name, block in local.blocks : name => merge(
      { for k, v in block : k => v if !contains(local.environments, k) },
      try(block[var.environment], {})
    )
  }
}
