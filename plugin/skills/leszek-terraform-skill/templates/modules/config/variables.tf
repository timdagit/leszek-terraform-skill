variable "environment" {
  type        = string
  nullable    = false
  description = "Environment name; must be listed in global.environments in the config file."
}

variable "config_file" {
  type        = string
  default     = null
  description = "Path to the YAML config file. Defaults to ../../config/main.config.yml relative to the root module."
}
