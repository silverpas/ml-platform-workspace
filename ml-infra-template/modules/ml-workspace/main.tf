# One Azure ML workspace for a department, with everything it needs:
#   1. a storage account   - files: datasets, models, job logs
#   2. a key vault         - the workspace's own passwords and keys
#   3. Application Insights (+ Log Analytics) - monitoring logs
#   4. a container registry - the Python environments of the jobs, built once and reused
#   5. the Azure ML workspace itself
#
# No compute: each use case gets its own cluster from the ml-project module,
# with the project's identity and tags (data access and costs per project).
#
# Everything is created INSIDE an existing resource group, so `terraform destroy`
# removes exactly these resources and nothing else in that group.

# Look up the existing resource group (data = read, don't create).
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# Who is running Terraform: needed for the key vault's tenant.
data "azurerm_client_config" "current" {}

locals {
  location = data.azurerm_resource_group.this.location

  # "-dev" when an environment is given, "" otherwise (the default).
  env_part = var.environment == null ? "" : "-${var.environment}"

  # Storage account, key vault and container registry names must be unique in
  # ALL of Azure, max 24 characters, and some allow no hyphens. So: a short
  # prefix + the department without hyphens + 6 characters derived from the
  # resource group and environment (always the same for the same inputs,
  # different for others).
  dept_compact = substr(replace(var.department, "-", ""), 0, 10)
  suffix       = substr(md5("${data.azurerm_resource_group.this.id}${local.env_part}"), 0, 6)

  default_names = {
    workspace          = "mlw-${var.department}${local.env_part}"
    storage_account    = "stml${local.dept_compact}${local.suffix}"
    key_vault          = "kv-ml-${local.dept_compact}-${local.suffix}"
    container_registry = "crml${local.dept_compact}${local.suffix}"
    log_analytics      = "log-mlw-${var.department}${local.env_part}"
    app_insights       = "appi-mlw-${var.department}${local.env_part}"
  }

  # A name given in var.names wins; otherwise the default above.
  names = {
    for key, default in local.default_names : key => coalesce(var.names[key], default)
  }

  tags = merge(var.tags, {
    department = var.department
    owner      = var.owner
    managed_by = "terraform"
  }, var.environment == null ? {} : { environment = var.environment })
}

# 1. Storage for the workspace's files.
resource "azurerm_storage_account" "workspace" {
  name                            = local.names.storage_account
  resource_group_name             = var.resource_group_name
  location                        = local.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS" # one region, cheapest; enough for ML artifacts
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false # nothing in it can be made public
  tags                            = local.tags
}

# 2. Key vault for the workspace's secrets.
resource "azurerm_key_vault" "workspace" {
  name                       = local.names.key_vault
  resource_group_name        = var.resource_group_name
  location                   = local.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true # access through Azure roles, not access policies
  soft_delete_retention_days = 7    # the minimum: a deleted vault is kept 7 days
  # ASSUMPTION: no purge protection, so a sandbox can be fully deleted.
  # Production setups often require purge_protection_enabled = true.
  purge_protection_enabled = false
  tags                     = local.tags
}

# 3. Monitoring: Application Insights stores its data in Log Analytics.
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = local.names.log_analytics
  resource_group_name = var.resource_group_name
  location            = local.location
  sku                 = "PerGB2018" # pay per GB of logs; ML jobs write very little
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "workspace" {
  name                = local.names.app_insights
  resource_group_name = var.resource_group_name
  location            = local.location
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  application_type    = "web"
  tags                = local.tags
}

# 4. Container registry. Created here (not by Azure ML on the first job) so
#    Terraform knows about it and `terraform destroy` removes it too.
resource "azurerm_container_registry" "workspace" {
  name                = local.names.container_registry
  resource_group_name = var.resource_group_name
  location            = local.location
  sku                 = "Basic" # the cheapest tier, enough for a few environments
  admin_enabled       = false   # no shared password; the workspace uses its identity
  tags                = local.tags
}

# 5. The Azure ML workspace, linked to the four resources above.
resource "azurerm_machine_learning_workspace" "this" {
  name                          = local.names.workspace
  resource_group_name           = var.resource_group_name
  location                      = local.location
  storage_account_id            = azurerm_storage_account.workspace.id
  key_vault_id                  = azurerm_key_vault.workspace.id
  application_insights_id       = azurerm_application_insights.workspace.id
  container_registry_id         = azurerm_container_registry.workspace.id
  public_network_access_enabled = var.public_network_access
  tags                          = local.tags

  # The workspace's own identity, used to reach its storage, vault and registry.
  identity {
    type = "SystemAssigned"
  }
}
