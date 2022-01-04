# Solution Variables
#### Begin by collecting the following information for authenticating to various Azure services. These variables will be used in both the initialization script and the reoccurring Log Task.

Azure AD Application ID (**$aadAppId**)   
Targeted Azure Subscription (**$azSubscription**)  
Targeted Tenant ID (**$tid**)  
Certificate Path (**$cPath**) specify the path of where a certificate has been installed on local machines ie “Cert:\CurrentUser\My”  
Certificate Subject Name (**$cSubject**), assuming this is unique. If not unique, modify $cThumbprint logic  
Key Vault (**$kv**) name is where our secrets are being stored  

#### Additionally, collect the following variables:
Azure Resource Group (**$azRG**)  
Log Analytics Workspace (**$wkspc**) name where custom logs will be stored  
Azure Storage (**$azStorage**) name where our container will exist  
Azure Container (**$azContainer**) is the storage container where blob will be exist  
Key Vault Secret (**$kvSecretName**) is used for retrieving blob storage   

#### Then define the following variables:
Log name (**$logname**) is the name of the log file that can be used for troubleshooting failures  
File name (**$fileName**) of the scheduled task & residing directory. Should also match the Solution Package (Azure Storage blob) for simplicity  
Current Time (**$curTime**) is used for defining the daily run time of log collection on the individual device. Can optionally be set. Currently defaults to time at which initialization script is run   
