


$RESOURCE_GROUP_NAME="rgOpenAIChat3"
$LOCATION="eastasia"
#for DB
#��ȫ��Ψһ
$SQL_SERVER_NAME="<your unique sql server name>"
$ADMIN_USERNAME="<your admin username>"
$ADMIN_PASSWORD=Read-Host "Enter the admin password"
$DB_NAME="dbGPT"

#for APIM
#��ȫ��Ψһ
$SVC_NAME="<your unique apim name>"
$API_ID="azuregpt-api"
$AOAI_DEPLOYMENT_ID="<your deployment id>"
$AOAI_MODEL_ID="<your model id>"
$AOAI_KEY=$AOAI_KEY = Read-Host "Enter the Azure OpenAI key"
#���񴴽���ɻᷢ�ʼ�֪ͨ
$APIM_PUBLISHER_EMAIL="<your email>"
$PUBLISHER="<your publisher name>"

#for webapp
$VUE_APP_APIM_HOST=$SVC_NAME + ".azure-api.net"
#�ȴ�API���񴴽�����ֶ���Portal��д
$VUE_APP_APIM_KEY="xxx"
#��ȫ��Ψһ, �ɸ�Ϊ�Լ����׼ǵ����֡�bot���ʵĵ�ַΪ https://<your app name>.azurewebsites.net
$APP_NAME="chat$(Get-Date -Format 'MMddHHmmss')"
#������������Լ��ģ����Բ��ġ�������޺�����Լ��ľ��񣬿��Ը�Ϊ�Լ��ľ����ַ
$DOCKER_IMAGE="radezheng/tsgpt:basic"



# create resource group
Write-Host "Creating resource group..."
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

Set-Location -Path $PWD
$job = Start-Job -FilePath "apim.ps1" -ArgumentList $RESOURCE_GROUP_NAME, $LOCATION, $SVC_NAME, $API_ID, $AOAI_DEPLOYMENT_ID, $AOAI_MODEL_ID, $AOAI_KEY, $APIM_PUBLISHER_EMAIL, $PUBLISHER

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
  --compute-model "Provisioned" --max-size 32GB --zone-redundant false `
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
az appservice plan create --name $APP_NAME'-plan' --resource-group $RESOURCE_GROUP_NAME --sku B1 --is-linux

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

Write-Host "��Ҫ�ֶ� ���� apim policy(./apim/policy.xml), ����ȡ apim key ���µ� web app �Ļ���������"