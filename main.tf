data "azurerm_subscription" "current" {}


resource "azurerm_management_group" "vmpolytesti" {
  display_name = "vmpolymonitesti"
}

resource "azurerm_policy_definition" "vmpolytesti" {
  name                = "vmpolytesti"
  policy_type         = "Custom"
  mode                = "All"
  display_name        = "vmpolytesti"
  management_group_id = azurerm_management_group.vmpolytesti.id

  metadata = jsonencode(
    {
      createdBy = "1f831b49-a2ab-4005-b63c-c907f8bb07a6"
      createdOn = "2022-11-14T10:50:32.5626468Z"
      preview   = true
      updatedBy = null
      updatedOn = null
      version   = "1.1.1-preview"
    }
  )

  parameters = jsonencode(
    {
      effect = {
        allowedValues = [
          "DeployIfNotExists",
          "Disabled",
        ]
        defaultValue = "DeployIfNotExists"
        metadata = {
          description = "Enable or disable the execution of the policy"
          displayName = "Effect"
        }
        type = "String"
      }
      enableProcessesAndDependencies = {
        allowedValues = [
          true,
          false,
        ]
        defaultValue = false
        metadata = {
          description = "This is the flag for enabling processes and dependencies data collection in VMInsights"
          displayName = "Enable Processes and Dependencies"
        }
        type = "Boolean"
      }

      userGivenDcrName = {
        defaultValue = "ama-vmi-default"
        metadata = {
          description = "This is the name of the AMA-VMI Data Collection Rule(DCR)"
          displayName = "Name of the Data Collection Rule(DCR)"
        }
        type = "String"
      }
      workspaceResourceId = {
        metadata = {
          assignPermissions = true
          description       = "Select Log Analytics workspace from dropdown list. If this workspace is outside of the scope of the assignment you must manually grant 'Log Analytics Contributor' permissions (or similar) to the policy assignment's principal ID."
          displayName       = "Log Analytics workspace"
          strongType        = "omsWorkspace"
        }
        type = "String"
      }
    }
  )
  policy_rule = jsonencode(
    {
      if = {
        equals = "Microsoft.Compute/virtualMachines"
        field  = "type"
      }
      then = {
        details = {
          deployment = {
            properties = {
              mode = "incremental"
              parameters = {
                enableProcessesAndDependencies = {
                  value = "[parameters('enableProcessesAndDependencies')]"
                }
                resourceGroup = {
                  value = "[resourceGroup().name]"
                }
                userGivenDcrName = {
                  value = "[parameters('userGivenDcrName')]"
                }
                vmName = {
                  value = "[field('name')]"
                }
                workspaceResourceId = {
                  value = "[parameters('workspaceResourceId')]"
                }
              }
              template = {
                "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
                contentVersion = "1.0.0.0"
                parameters = {
                  enableProcessesAndDependencies = {
                    type = "bool"
                  }
                  resourceGroup = {
                    type = "string"
                  }
                  userGivenDcrName = {
                    type = "string"
                  }
                  vmName = {
                    type = "string"
                  }
                  workspaceResourceId = {
                    type = "string"
                  }
                }
                resources = [
                  {
                    apiVersion = "2020-08-01"
                    name       = "get-workspace-region"
                    properties = {
                      mode = "Incremental"
                      template = {
                        "$schema"      = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
                        contentVersion = "1.0.0.0"
                        outputs = {
                          workspaceLocation = {
                            type  = "string"
                            value = "[reference(parameters('workspaceResourceId'), '2020-08-01', 'Full').location]"
                          }
                        }
                        resources = []
                      }
                    }
                    type = "microsoft.resources/deployments"
                  },
                  {
                    apiVersion = "2020-08-01"
                    condition  = "[not(parameters('enableProcessesAndDependencies'))]"
                    name       = "[concat(variables('dcrDeployment'),'-noDA')]"
                    properties = {
                      mode = "Incremental"
                      parameters = {
                        workspaceRegion = {
                          value = "[reference('get-workspace-region').outputs.workspaceLocation.value]"
                        }
                      }
                      template = {
                        "$schema"      = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
                        contentVersion = "1.0.0.0"
                        parameters = {
                          workspaceRegion = {
                            type = "string"
                          }
                        }
                        resources = [
                          {
                            apiVersion = "2021-04-01"
                            location   = "[[parameters('workspaceRegion')]"
                            name       = "[variables('dcrName')]"
                            properties = {
                              dataFlows = [
                                {
                                  destinations = [
                                    "VMInsightsPerf-Logs-Dest",
                                  ]
                                  streams = [
                                    "Microsoft-InsightsMetrics",
                                  ]
                                },
                              ]
                              dataSources = {
                                performanceCounters = [
                                  {
                                    counterSpecifiers = [
                                      "\\VmInsights\\DetailedMetrics",
                                    ]
                                    name                       = "VMInsightsPerfCounters"
                                    samplingFrequencyInSeconds = 60
                                    scheduledTransferPeriod    = "PT1M"
                                    streams = [
                                      "Microsoft-InsightsMetrics",
                                    ]
                                  },
                                ]
                              }
                              description = "Data collection rule for VM Insights."
                              destinations = {
                                logAnalytics = [
                                  {
                                    name                = "VMInsightsPerf-Logs-Dest"
                                    workspaceResourceId = "[parameters('workspaceResourceId')]"
                                  },
                                ]
                              }
                            }
                            type = "Microsoft.Insights/dataCollectionRules"
                          },
                        ]
                      }
                    }
                    type = "microsoft.resources/deployments"
                  },
                  {
                    apiVersion = "2020-08-01"
                    condition  = "[parameters('enableProcessesAndDependencies')]"
                    name       = "[concat(variables('dcrDeployment'),'-DA')]"
                    properties = {
                      mode = "Incremental"
                      parameters = {
                        workspaceRegion = {
                          value = "[reference('get-workspace-region').outputs.workspaceLocation.value]"
                        }
                      }
                      template = {
                        "$schema"      = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
                        contentVersion = "1.0.0.0"
                        parameters = {
                          workspaceRegion = {
                            type = "string"
                          }
                        }
                        resources = [
                          {
                            apiVersion = "2021-04-01"
                            location   = "[[parameters('workspaceRegion')]"
                            name       = "[variables('dcrName')]"
                            properties = {
                              dataFlows = [
                                {
                                  destinations = [
                                    "VMInsightsPerf-Logs-Dest",
                                  ]
                                  streams = [
                                    "Microsoft-InsightsMetrics",
                                  ]
                                },
                                {
                                  destinations = [
                                    "VMInsightsPerf-Logs-Dest",
                                  ]
                                  streams = [
                                    "Microsoft-ServiceMap",
                                  ]
                                },
                              ]
                              dataSources = {
                                extensions = [
                                  {
                                    extensionName     = "DependencyAgent"
                                    extensionSettings = {}
                                    name              = "DependencyAgentDataSource"
                                    streams = [
                                      "Microsoft-ServiceMap",
                                    ]
                                  },
                                ]
                                performanceCounters = [
                                  {
                                    counterSpecifiers = [
                                      "\\VmInsights\\DetailedMetrics",
                                    ]
                                    name                       = "VMInsightsPerfCounters"
                                    samplingFrequencyInSeconds = 60
                                    scheduledTransferPeriod    = "PT1M"
                                    streams = [
                                      "Microsoft-InsightsMetrics",
                                    ]
                                  },
                                ]
                              }
                              description = "Data collection rule for VM Insights."
                              destinations = {
                                logAnalytics = [
                                  {
                                    name                = "VMInsightsPerf-Logs-Dest"
                                    workspaceResourceId = "[parameters('workspaceResourceId')]"
                                  },
                                ]
                              }
                            }
                            type = "Microsoft.Insights/dataCollectionRules"
                          },
                        ]
                      }
                    }
                    type = "microsoft.resources/deployments"
                  },
                  {
                    apiVersion = "2020-06-01"
                    dependsOn = [
                      "[concat(variables('dcrDeployment'),'-DA')]",
                      "[concat(variables('dcrDeployment'),'-noDA')]",
                    ]
                    name = "[variables('dcraDeployment')]"
                    properties = {
                      expressionEvaluationOptions = {
                        scope = "inner"
                      }
                      mode = "Incremental"
                      parameters = {
                        dcrId = {
                          value = "[variables('dcrId')]"
                        }
                        dcraName = {
                          value = "[variables('dcraName')]"
                        }
                        vmName = {
                          value = "[parameters('vmName')]"
                        }
                      }
                      template = {
                        "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
                        contentVersion = "1.0.0.0"
                        parameters = {
                          dcrId = {
                            type = "string"
                          }
                          dcraName = {
                            type = "string"
                          }
                          vmName = {
                            type = "string"
                          }
                        }
                        resources = [
                          {
                            apiVersion = "2019-11-01-preview"
                            name       = "[parameters('dcraName')]"
                            properties = {
                              dataCollectionRuleId = "[parameters('dcrId')]"
                              description          = "Association of data collection rule for VMInsights. Deleting this association will stop the insights flow for this virtual machine."
                            }
                            type = "Microsoft.Compute/virtualMachines/providers/dataCollectionRuleAssociations"
                          },
                        ]
                        variables = {}
                      }
                    }
                    resourceGroup = "[parameters('resourceGroup')]"
                    type          = "Microsoft.Resources/deployments"
                  },
                ]
                variables = {
                  dcrDeployment  = "[concat('dcrDeployment-', uniqueString(deployment().name))]"
                  dcrId          = "[concat('/subscriptions/', variables('subscriptionId'), '/resourceGroups/', parameters('resourceGroup'), '/providers/Microsoft.Insights/dataCollectionRules/', variables('dcrName'))]"
                  dcrName        = "[concat('MSVMI-', parameters('userGivenDcrName'), '-dcr')]"
                  dcraDeployment = "[concat('dcraDeployment-', uniqueString(deployment().name))]"
                  dcraName       = "[concat(parameters('vmName'), '/Microsoft.Insights/VMInsights-Dcr-Association')]"
                  subscriptionId = "[subscription().subscriptionId]"
                }
              }
            }
          }
          existenceCondition = {
            allOf = [
              {
                equals = "[concat('/subscriptions/', subscription().subscriptionId, '/resourceGroups/', resourceGroup().name, '/providers/Microsoft.Insights/dataCollectionRules/MSVMI-', parameters('userGivenDcrName'), '-dcr')]"
                field  = "Microsoft.Insights/dataCollectionRuleAssociations/dataCollectionRuleId"
              },
              {
                equals = "VMInsights-Dcr-Association"
                field  = "name"
              },
            ]
          }
          roleDefinitionIds = [
            "/providers/microsoft.authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa",
            "/providers/microsoft.authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293",
          ]
          type = "Microsoft.Insights/dataCollectionRuleAssociations"
        }
        effect = "[parameters('effect')]"
      }
    }
  )

  # (1 unchanged attribute hidden)

  timeouts {}
}





resource "azurerm_subscription_policy_assignment" "vmpolytesti" {
  name                 = "vmpolytesti"
  policy_definition_id = azurerm_policy_definition.vmpolytesti.id
  subscription_id      = data.azurerm_subscription.current.id
}
resource "azurerm_management_group_policy_assignment" "vmpolytesti" {
  name                 = "vmpolytesti"
  policy_definition_id = azurerm_policy_definition.vmpolytesti.id
  management_group_id  = azurerm_management_group.vmpolytesti.id
}

#terraform import azurerm_policy_definition.examplePolicy '/subscriptions/90579509-9158-4fff-b9ef-9fcef1e8f30b/providers/Microsoft.Authorization/policyDefinitions/Deploy a VMInsights Data Collection Rule and Data Collection Rule Association for all the VMs in the Resource Group'
