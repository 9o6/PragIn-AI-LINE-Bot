// playground:https://bicepdemo.z22.web.core.windows.net/
param location string = resourceGroup().location
param random string
param secret string
param access string
param containerRegistryName string
param containerVer string
param appsPort string
param aoaiApiKey string
param aoaiApiBase string
param aoaiApiEngineName string

var appInsightsName = 'AppInsights'

param openAiAccountName string = 'OpenAI-${uniqueString(resourceGroup().id)}'
param openAIModelDeploymentName string = 'OpenAIDev-${uniqueString(resourceGroup().id)}'
//param openAiRegion string = 'East US'
param openAiRegion string = 'South Central US'

/*
// https://github.com/Azure-Samples/cosmosdb-chatgpt/blob/4ce83e6236cf311beb3a7b2367932c8c7b429268/azuredeploy.bicep#L111
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: openAiAccountName
  location: openAiRegion
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: openAiAccountName
    publicNetworkAccess: 'Enabled'
  }
}

resource openAiAccountName_openAIModelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2022-12-01' = {
  parent: openAiAccount
  name: openAIModelDeploymentName
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4'
      version: '0314'
    }
    scaleSettings: {
      scaleType: 'Standard'
    }
  }
}
*/

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' existing = {
  name: containerRegistryName
}

var containerImageName = 'linebot/aca'
var containerImageTag = containerVer

// https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.app/container-app-scale-http/main.bicep
@description('Specifies the name of the log analytics workspace.')
param containerAppLogAnalyticsName string = 'log-${uniqueString(resourceGroup().id)}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: containerAppLogAnalyticsName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId:logAnalytics.id
  }
}

resource managedEnvironments 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: 'managedEnv'
  location: location
  properties: {
    daprAIInstrumentationKey:appInsights.properties.InstrumentationKey
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
  sku: {
    name: 'Consumption'
  }
}

// https://learn.microsoft.com/ja-jp/dotnet/orleans/deployment/deploy-to-azure-container-apps
// https://github.com/microsoft/azure-container-apps/blob/main/docs/templates/bicep/main.bicep
resource containerApps 'Microsoft.App/containerApps@2022-10-01' = {
  name: 'container-apps'
  location: location
  properties: {
    managedEnvironmentId: managedEnvironments.id
    configuration: {
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'reg-pswd-d6696fb9-a98d'
        }
      ]
      secrets: [
        {
          name: 'reg-pswd-d6696fb9-a98d'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        transport: 'auto'
        targetPort: appsPort
      }
    }
    template: {
      containers: [
        {
          name: 'line-bot-container-apps'
          image: '${containerRegistry.name}.azurecr.io/${containerImageName}:${containerImageTag}'
          command: []
          resources: {
            cpu: json('1.0')
            memory: '2Gi'

          }
          env: [
            {
              name: 'LINE_CHANNEL_SECRET'
              value: secret
            }
            {
              name: 'LINE_CHANNEL_ACCESS_TOKEN'
              value: access
            }
            {
              name: 'OPENAI_API_KEY'
              value: aoaiApiKey
            }
            {
              name: 'OPENAI_API_BASE'
              value: aoaiApiBase
            }
            {
              name: 'OPENAI_API_ENGINE_NAME'
              value: aoaiApiEngineName
            }
          ]
        }
      ]
      scale: {
        maxReplicas: 1
        minReplicas: 1
      }
    }
  }
}

output acaUrl string = 'https://${containerApps.properties.configuration.ingress.fqdn}'
