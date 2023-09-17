$RESOURCE_GROUP_NAME="rgOpenAIChat"
$LOCATION="eastasia"

# for DB
$SQL_SERVER_NAME="<Your Unique SQLServer Name>"                 # 需全球唯一
$ADMIN_USERNAME="SQLAdmin"
$ADMIN_PASSWORD=Read-Host "Enter the admin password"            # 设置一个密码，不能太简单
$DB_NAME="dbGPT"

#for APIM
$SVC_NAME="<Your Unique APIM Name>"                             # 需全球唯一
$API_ID="azuregpt-api"
$AOAI_DEPLOYMENT_ID="<Your OpenAI Resource Name>"               # 填入AOAI服务名称
$AOAI_MODEL_ID="<Your Deployment ID>"                           # 注意是部署的名称，可在Azure AI Studio中查看
$AOAI_KEY = Read-Host "Enter the Azure OpenAI key"

# 服务创建完成会发邮件通知
$APIM_PUBLISHER_EMAIL="<your email>"
$PUBLISHER="<your publisher name>"

#for Web App
$VUE_APP_APIM_HOST=$SVC_NAME + ".azure-api.net"
$VUE_APP_APIM_KEY="xxx"                                       # 等待API服务创建完成手动在Portal填写
$APP_NAME="MyChatBot$(Get-Date -Format 'MMddHHmmss')"         # 需全球唯一
$DOCKER_IMAGE="radezheng/tsgpt:basic"                         # 可不改/改为自己的镜像地址



# create resource group
Write-Host "Creating resource group..."
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

Set-Location -Path $PWD
$job = Start-Job -FilePath "apim.ps1" -ArgumentList $RESOURCE_GROUP_NAME, $LOCATION, $SVC_NAME, $API_ID, $AOAI_DEPLOYMENT_ID, $AOAI_MODEL_ID, $AOAI_KEY, $APIM_PUBLISHER_EMAIL, $PUBLISHER, $PWD

# create sql server
Write-Host "Creating Azure SQL Server..." + $SQL_SERVER_NAME
az sql server create --name $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP_NAME `
    --location $LOCATION --admin-user $ADMIN_USERNAME --admin-password $ADMIN_PASSWORD

# set firewall rule to allow current client public ip
$ip = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" | Select-Object -ExpandProperty ip
az sql server firewall-rule create --name "AllowClients" --server $SQL_SERVER_NAME `
  --resource-group $RESOURCE_GROUP_NAME --start-ip-address $ip --end-ip-address $ip

#set firewall rule to allow azure services
az sql server firewall-rule create --resource-group $RESOURCE_GROUP_NAME --server $SQL_SERVER_NAME  `
  --name AllowAllWindowsAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0


# create database
Write-Host "Creating  Azure SQL DB..." + $DB_NAME
az sql db create --name $DB_NAME --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP_NAME `
  --edition "GeneralPurpose" --family "Gen5" --capacity 2 `
  --compute-model "Provisioned" --license-type BasePrice --max-size 32GB --zone-redundant false `
  --backup-storage-redundancy Local --collation "Latin1_General_100_BIN2_UTF8"



$DB_USER=$ADMIN_USERNAME
$DB_PASSWORD=$ADMIN_PASSWORD
$DB_SERVER=$SQL_SERVER_NAME + ".database.windows.net"
$DB_DATABASE=$DB_NAME

Write-Host "Creating  Azure SQL Table and Data, need sqlcmd ..."
$sqlcmd = "sqlcmd -S $DB_SERVER -d $DB_NAME -U $ADMIN_USERNAME -P $ADMIN_PASSWORD -i .\table.sql"
Invoke-Expression $sqlcmd

# Create web app
Write-Host "Creating web app plan..." + $APP_NAME + "-plan"
az appservice plan create --name $APP_NAME'-plan' --resource-group $RESOURCE_GROUP_NAME --sku B3 --is-linux

Write-Host "Creating web app..." + $APP_NAME
az webapp create --resource-group $RESOURCE_GROUP_NAME --plan $APP_NAME'-plan'  --name $APP_NAME --deployment-container-image-name $DOCKER_IMAGE

Write-Host "deploy container to web app..." 
az webapp config container set --name $APP_NAME --resource-group $RESOURCE_GROUP_NAME --docker-custom-image-name $DOCKER_IMAGE --docker-registry-server-url https://index.docker.io

# Set environment variables
Write-Host "Setting environment variables..."
az webapp config appsettings set --resource-group $RESOURCE_GROUP_NAME --name $APP_NAME --settings VUE_APP_APIM_HOST=$VUE_APP_APIM_HOST VUE_APP_APIM_KEY=$VUE_APP_APIM_KEY DB_USER=$DB_USER DB_PASSWORD=$DB_PASSWORD DB_SERVER=$DB_SERVER DB_DATABASE=$DB_DATABASE NODE_PORT=3000

# Restart web app
Write-Host "Restarting web app..."
az webapp restart --resource-group $RESOURCE_GROUP_NAME --name $APP_NAME

#show web app url
Write-Host "Web app url:"
az webapp show --resource-group $RESOURCE_GROUP_NAME --name $APP_NAME --query defaultHostName --output tsv

Write-Host "Waiting for apim job to finish...run this command to check the log:" `
 " Get-Job | Sort-Object -Property PSBeginTime -Descending | Select-Object -First 1 | Receive-Job"
Get-Job | Sort-Object -Property PSBeginTime -Descending | Select-Object -First 1 | Receive-Job

# Write-Host "需要手动 更新 apim policy(./apim/policy.xml), 并获取 apim key 更新到 web app 的环境变量中"
