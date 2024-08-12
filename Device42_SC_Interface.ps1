<#	
	.NOTES
	===========================================================================	 
	 Created on:   	31/01/2024
	 Created by:   	Kevin Debono 
	 Organization: 	
	 Filename:     	Device42_SC_Interface.ps1
     Version:       2.0 (12/07/2024)
	===========================================================================
	.DESCRIPTION
    Device42/Tenable SC Plus interface
#>


Param
(
    [Parameter(Mandatory = $true)][string]$PMPServer,
    [Parameter(Mandatory = $true)][string]$PMPToken,
    [string]$SCServer="192.168.0.10",
    [string]$SCAPI = "Tenable SC API_INT",
    [ValidateSet("UpdateAssets", "CABaseline", "UpdateCAList", "GetUsers")]
    [string]$Mode = "UpdateAssets",
    [string]$CriticalLabel = "Asset is a critical asset",
    [string]$NotCriticalLabel = "Asset in not a critical asset anymore",
    [string]$Inventory = 'AssetInventory.xlsx'
)


<#
    **************************************************
    
    AddOwnerTwo()

    Purpose:  Add Asset Owner from Device42

    Input:    $Owner  -  Asset SME
              
    Output:   None                  

    **************************************************
#>
function AddOwnerTwo($Owner)
{

    $NoDom = $Owner.split("\")
    
    foreach($SME in $SMEList)
    {
        if($SME -match $NoDom[1])
        {
            $Team = $SME.Split(",")

            for($iIndex=0; $iIndex -lt $AssetsFile.count; $iIndex++)
            {
                if($AssetsLists[$iIndex].AssetGroup -match $Team[0])
                {
                    AddIPs -Assets ([ref]$AssetsLists) -IPList $json[$Index].all_listener_device_ips -AssetIndex $iIndex -IPcount $json[$Index].'IP Addresses Discovered'   
                    break
                }
            }
        }
    }
}


<#
    **************************************************
    
    GetAccessToken()

    Purpose:  Generates as access token for Device42 API access

    Input:    $Credentials  -  Device42 credentials
              

    Output:   Device42 API access token

    **************************************************
#>
function GetAccessToken($Credentials)
{

    $bytes = [System.Text.Encoding]::UTF8.getBytes($credentials)
    $encodedAuth = [System.Convert]::ToBase64String($bytes)
    $d42_headers = @{Authorization = "Basic $encodedAuth"}

    $body = @{grant_type = "client_credentials"}

    $d42_url = "https://device42/tauth/1.0/token/"

    $result = Invoke-RestMethod -Uri $d42_url -Headers $d42_headers -Method post -Body $body
    $AccessToken = $result.token

    return $AccessToken
}

<#
    **************************************************
    
    GetFilename()

    Purpose:  Generates a filename for the log.  A new log
              will be created everytime the script is executed

    Input:    $Prefix  -  Log filename prefix              

    Output:   The log filename

    **************************************************
#>
function GetFilename($Prefix)
{		
	$szDate = (Get-Date).ToString("ddMMyyHHmm")
    $szFilename = $Prefix + "_" + $szDate + ".log"
    return $szFilename
}

<#
    ************************************************** 
    
    WriteLog()

    Purpose:  Add a log entry to the log file

    Input:    $LogString   -  The log entry
              $LogFilename -  Log filename
              $flgData     -  If flag is false the current data/time will be added before the entry
              
    Output:   NONE

    **************************************************
#>
function WriteLog([string]$LogString, [string]$LogFilename, [boolean]$flgDate)
{    
    
    if($flgDate -eq $false)
    {
        $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
        $LogMessage = "$Stamp $LogString"
        Add-content $LogFilename -value $LogMessage        
    }
    elseif($flgDate -eq $true)
    {
        Add-content $LogFilename -value $LogString
    }    
}

<#
    **************************************************
    
    GetUsers()

    Purpose:    Get the users from Tenable SC 

    Input:                                                      

    Output:     None

    **************************************************
#>
function GetUsers()
{

    Get_API -ResourceID $SCAPI -AccessKey ([ref]$AccessKey) -SecretKey ([ref]$SecretKey)
    
    $url = 'https://' + $SCServer + '/rest/user' + '?fields=id,username,firstname,lastname,email,group'

    $flgNewRun = $true
    $flgNewTeam = $True
    
    $Headers = @{}
    $Headers.Add("x-apikey", "accessKey=$AccessKey;secretKey=$SecretKey")    
    $Headers.Add("Host","92.168.0.15")
    $Headers.Add("Content-Type","application/json")

    $Request = Invoke-RestMethod -Headers $Headers -Method get -uri $url -body $Body -UseBasicParsing        
    $SMEs = $Request.response

    
    foreach($SME in $SMEs)
    {
        $flgNewTeam = $true
        for ($iIndex=0; $iIndex -le $SMEList.count; $iIndex++)
        {
            if($SMEList[$iIndex] -match $SME.group.name)            
            {
                $SMEList[$iindex] = $SMEList[$iindex] + "," + $SME.username.ToLower().TrimEnd("bxa")
                $flgNewTeam = $false
                break
            }
            elseif($SMEList.count -eq 0)
            {
                $SMEList.add($SME.group.name)
                
                if ($flgNewRun -eq $False) {$iIndex = $SMEList.count - 1}
                $SMEList[$iIndex] = $SMEList[$iIndex] + "," + $SME.username.ToLower().TrimEnd("bxa")
                $flgNewRun = $False
                $flgNewTeam = $false
                break
            }            
        }
        if($flgNewTeam -eq $True)
        {
            $SMEList.add($SME.group.name)
            $SMEList[$iIndex-1] = $SMEList[$iIndex-1] + "," + $SME.username.ToLower().TrimEnd("bxa")
            $flgNewRun = $False                            
        }
        
    }        
    
}

<#
    **************************************************
    
    AddIPs()

    Purpose:    Add IP addresses to the Tenable SC asset list

    Input:      $Assets      -   The assets list in Tenable SC
                $IPList      -   The IP addresses to add to the asset list
                $AssetIndex  -   The index pointint ot the current asset list
                $IPCount     -   The number of IP addresses to be added

    Output:     None

    **************************************************
#>
function AddIPs([ref]$Assets, $IPList, $AssetIndex, $IPCount)
{        
    if($IPCount -gt 0)
    {        
        $Assets.Value[$AssetIndex].Asset = $IPList.trim() + "," +  $Assets.Value[$AssetIndex].Asset
    }

}

<#
    **************************************************
    
    SplitIPList()

    Purpose:    Split the IPs in the json property all_listener_device_ips.length

    Input:      $IPList  -  The list of IP addresses          

    Output:     The IP addresses as an array

    **************************************************
#>
function SplitIPList($IPList)
{
    $MultiIPs = $IPList.split(",")
    if ($MultiIPs.count -gt 1)
    {
        return $MultiIPs
    }
}


<#
    **************************************************
    
    GetAssetInventory()

    Purpose:    Load Assets inventory Excel sheet and compare criticality

    Input:      $Json        -   JSON object with all Assets from Device42              

    Output:     NONE

    **************************************************
#>
function GetAssetInventory($Json)
{
    
    $IPList = New-Object System.Collections.ArrayList

    #Create an Object Excel.Application using Com interface
    $objExcel = New-Object -ComObject Excel.Application
    #Disable the 'visible' property so the document won't open in excel
    $objExcel.Visible = $false

    $CurrentFolder = $PSScriptRoot
    $WorkbookName = $CurrentFolder + '\Inventory\' + $Inventory
    $workbook = $objExcel.Workbooks.Open($WorkbookName)              
    $Worksheet = $WorkBook.sheets.item("owssvr")

    $iRow = 2    
    $Col = "A"
    
    while($WorkSheet.Range($Col + $iRow).Text -ne "")
    {
        for($Index = 0; $Index -le $json.length; $Index++)
        {                                               
            Write-Host "Processing the asset $($json[$Index].Device_Name) with IPs $($json[$Index].all_listener_device_ips)"            
            
            if(($WorkSheet.Range($Col + $iRow).Text -match $json[$Index].Device_name) -and ($WorkSheet.Range('C' + $iRow).Text -notmatch ''))
            {
                $AssetFound = $True
                if($WorkSheet.Range('L' + $iRow).Text -eq 'Yes')
                {
                    
                    if ($WorkSheet.Range('A' + $iRow).Text -match ".")
                    {
                        $Field = $WorkSheet.Range('A' + $iRow).Text
                        $AssetName = $Field.split('.')
                    }
                  
                    $body = @{}
                    $Body.add('name',"$Field")
                    $Body.add('key','Criticality')
                    $body.add('value','yes')
                    $body.add('type','yes/no')

                    $Body = ConvertTo-Json -Depth 10 -InputObject $Body
                    
                    $AccessToken = GetAccessToken -Credentials $Credentials
                    $d42_headers = @{Authorization = "Bearer $AccessToken"    
                        "Content-Type" = "application/json"}
                    
                    #Updating criticality of an asset
                    $d42_url = "https://device42/api/1.0/device/custom_field/"    
                    $result = Invoke-WebRequest -Uri $d42_url -Headers $d42_headers -Method put -Body $Body 
                    $JS_Result = $result | ConvertFrom-Json

                    break
                }
                else
                {
                    break
                }
            }
        }
        $iRow++
    }
}
<#
    **************************************************
    
    GetCritical()

    Purpose:    Get the assets list + criticality from Device42

    Input:      $Query  -  The Device42 query to execute

    Output:     The json response object containing the assets

    **************************************************
#>
function GetCritical($Query)
{
 
    WriteLog -LogString "Retreiving Device42 API key from PMP" -LogFilename $TransLogFilename

    Get_API -ResourceID 'Device42 Client_key' -AccessKey ([ref]$AccessKey) -SecretKey ([ref]$SecretKey)
    
    $d42_username = $AccessKey
    $d42_password = $SecretKey

    $Credentials = "$($d42_username):$($d42_password)"

    $AccessToken = GetAccessToken -Credentials $Credentials

    $d42_headers = @{Authorization = "Bearer $AccessToken"    
                "Content-Type" = "application/json"}
    
    $d42_url = "https://device42/services/data/v1.0/query/?saved_query_name=$Query&delimiter=,&header=yes&output_type=json"
    $result = Invoke-WebRequest -Uri $d42_url -Headers $d42_headers -Method Get
    
    if ($result.StatusCode -eq 200)
    {
        WriteLog -LogString "Successfully retrieve data from Device42" -LogFilename $TransLogFilename
    }
    else
    {
        WriteLog -LogString "Failed to retrieve data from Device42" -LogFilename $TransLogFilename
    }

    $json = $result | ConvertFrom-Json    

    if($Mode -eq 'CABaseline')
    {
        GetAssetInventory -Json $json
    }
    elseif($Mode -eq 'UpdateCAList')
    {
        return $json
    }
}

<#
    **************************************************
    
    SearchHost()

    Purpose:    Find an asset uuid and update ACR

    Input:      $HostIP      -   The asset Id of the Asset list to retrieve
                $AccessKey   -   Tenable SC API access key
                $SecretKey   -   Tenable SC API secret key              
                $Critical    -   Yes if the asset is critical, no or null if not critical

    Output:     NONE

    **************************************************
#>
function SearchHost($HostIP, $AccessKey, $SecretKey, $Critical)
{    

    $url = 'https://' + $SCServer + '/rest/hosts/search' + '?limit=50&startOffset=0&endOffset=50&sortField=name&sortDirection=DESC&paginated=true&fields=assetID,`
       name,ipAddress,os,systemType,macAddress,firstSeen,lastSeen,source,repID,netBios,dns,tenableUUID,acr,aes'
                    
    $Headers = @{}
    $Headers.Add("x-apikey", "accessKey=$AccessKey;secretKey=$SecretKey")    
    $Headers.Add("Host","192.168.0.30")
    $Headers.Add("Content-Type","application/json")
    
    $Body = @{}
    $Filter = New-Object System.Collections.ArrayList
    
    WriteLog -LogString  "Processing the asset with IPs $HostIP" -LogFilename $TransLogFilename    

    #Fetch Server to update
    $Filter.Add(@{"property"="ip";"operator"="eq";"value"="$HostIP";})    
    $Filters = @{"and"=$Filter;}
    
    $Body.Add("filters",$Filters)    
    $Body = ConvertTo-Json -Depth 10 -InputObject $Body
    
    $Request = Invoke-RestMethod -Headers $Headers -Method Post -uri $url -body $Body -UseBasicParsing    
    $Request.response.results 
    
    $AssetObject = $Request.response.results 
    
    WriteLog -LogString "$($AssetObject.netBios),$($AssetObject.uuid),$($AssetObject.ipaddress),$($AssetObject.os),$($AssetObject.acr.overwrittenScore),$($AssetObject.acr.score)" -LogFilename $TenableSCLogFilename
    WriteLog -LogString "Processing the asset $($AssetObject.netBios) with the IPs $($AssetObject.ipaddress)" -LogFilename $TransLogFilename    
    Write-Host "Processing the asset $($AssetObject.netBios) with IPs $($AssetObject.ipaddress)"

    $uuid = $Request.response.results.uuid
    $acr_Score = $Request.response.results.acr.overwrittenScore
    #$acr_Score = $Request.response.results.acr.score    

    #***********
    #Debug code
    if ($Critical -eq 'Yes')
    {
        Write-Host $Critical
    }
    #***********

    #Is it a critical asset
    if(($acr_Score -lt 8) -and ($Critical -eq 'Yes'))
    {

        WriteLog -LogString "ACR for asset $($AssetObject.ipaddress) will be set to critical" -LogFilename $TransLogFilename

        $Reasoning = New-Object System.Collections.ArrayList 
        $Reasoning.add(@{"id"=1;"lablel"="Business Critical"})
        $Reasoning = @{"reasoning"=$Reasoning;}

        $acr = @{"overwrittenScore"=9}
        $acr.Add("notes","$CriticalLabel")
        $acr.add("overwritten","true")
           
        $Body = $Reasoning + $acr        
        $Body = ConvertTo-Json -InputObject $Body

        UpdateACR -SCServer $SCServer -Headers $Headers -uuid $uuid -Body $Body -AssetObject $AssetObject
    }
    elseif(($acr_Score -ge 8) -and ($Critical -eq 'No' -or $Critical -eq $null))
    {
        WriteLog -LogString "ACR for asset $($AssetObject.ipaddress) will be removed from critical" -LogFilename $TransLogFilename

        $Reasoning = New-Object System.Collections.ArrayList 
        $Reasoning.add(@{"id"=4;"lablel"="ACR score changed"})
        $Reasoning = @{"reasoning"=$Reasoning;}

        $acr = @{"overwrittenScore"=5}
        $acr.Add("notes","$NotCriticalLabel")
        $acr.add("overwritten","true")
           
        $Body = $Reasoning + $acr        
        $Body = ConvertTo-Json -InputObject $Body
        
        UpdateACR -SCServer $SCServer -Headers $Headers -uuid $uuid -Body $Body -AssetObject $AssetObject
    }

}

<#
    **************************************************
    
    UpdateACR()

    Purpose:    Update the ACR for an Asset in Tenable SC

    Input:      $SCServer    -   Tenable SC Plus IP address
                $Headers     -   Web request header
                $uuid        -   Asset UUID in Tenable SC Plus
                $Body        -   Web request body 
              

    Output:     The list of IPs in the Asset list

    **************************************************
#>
function UpdateACR($SCServer, $Headers, $uuid, $Body, $AssetObject)
{

    if($uuid.Count -gt 1)
    {
        for($iIndex = 0; $iIndex -lt $uuid.Count; $iIndex++)
        {
            $url = 'https://' + $SCServer + "/rest/hosts/$($uuid[$iIndex])/acr"
            $Request = Invoke-WebRequest -Headers $Headers -Method Patch -uri $url -ContentType "application/json" -Body $Body
            if ($Request.StatusCode -eq 200)
            {
                WriteLog -LogString "ACR for asset $($AssetObject.ipaddress) updated successfully" -LogFilename $TransLogFilename
            }
            else
            {
                WriteLog -LogString "Failed to update ACR for asset $($AssetObject.ipaddress)" -LogFilename $TransLogFilename
            }
        }
    }
    else
    {
        $url = 'https://' + $SCServer + "/rest/hosts/$uuid/acr"
        $Request = Invoke-WebRequest -Headers $Headers -Method Patch -uri $url -ContentType "application/json" -Body $Body
        if ($Request.StatusCode -eq 200)
        {
            WriteLog -LogString "ACR for asset $($AssetObject.ipaddress) updated successfully" -LogFilename $TransLogFilename
        }
        else
        {
            WriteLog -LogString "Failed to update ACR for asset $($AssetObject.ipaddress)" -LogFilename $TransLogFilename
        }
    }

}

<#
    **************************************************
    
    GetAssets()

    Purpose:    Get an Asset list from Tenable SC

    Input:      $AssetID        -   The asset Id of the Asset list to retrieve
                $AccessKey      -   Tenable SC API access key
                $SecretKey      -   Tenable SC API secret key              

    Output:     The list of IPs in the Asset list

    **************************************************
#>
function GetAssets($AssetID, $AccessKey, $SecretKey)
{

    $SCServer = 'https://' + $SCServer + '/rest/asset/' + $AssetID    
    $Headers = @{}
    $Headers.Add("x-apikey", "accessKey=$AccessKey;secretKey=$SecretKey")

    $Request = Invoke-WebRequest -Headers $Headers -Method Get -uri $SCServer
    $AssetContent = ConvertFrom-Json -InputObject $Request.Content    
    $definedIPs = $AssetContent.response.typeFields.definedIPs

    return $definedIPs
}

<#
    **************************************************
    
    GetAssetsLists()

    Purpose:    Get all Asset lists from Tenable SC

    Input:      $AccessKey      -   Tenable SC API access key
                $SecretKey      -   Tenable SC API secret key              

    Output:     NONE

    **************************************************
#>
function GetAssetsLists($AccessKey, $SecretKey)
{

    $SCServer = 'https://' + $SCServer + '/rest/asset?fields=owner,repositories,ipCount'
    $Headers = @{}
    $Headers.Add("x-apikey", "accessKey=$AccessKey;secretKey=$SecretKey")

    $Request = Invoke-WebRequest -Headers $Headers -Method Get -uri $SCServer
    $AssetsLists = ConvertFrom-Json -InputObject $Request.Content    

}
<#
    **************************************************
    
    UpdateAssetList()

    Purpose:    Update the list of IPs in an Asset list

    Input:      $AssetID        -   The Asset ID of the Asset list to retrieve
                $AccessKey      -   Tenable SC API access key
                $SecretKey      -   Tenable SC API secret key
                $IPAddrs        -   The list of IPs to add to the Asset list
              
    Output:     NONE

    **************************************************
#>
Function UpdateAssetList($AssetID, $AccessKey, $SecretKey, $IPAddrs)
{

    $SCServer = 'https://' + $SCServer + '/rest/asset/' + $AssetID

    $Headers = @{}
    $Headers.Add("x-apikey", "accessKey=$AccessKey;secretKey=$SecretKey")
    
    $DefinedIPs = $IPAddrs
    $Body = @{'definedIPs'=$DefinedIPs}
    $Body = ConvertTo-Json -InputObject $Body
    $Request = Invoke-WebRequest -Headers $Headers -Method Patch -uri $SCServer -ContentType "application/json" -Body $Body
}

<#
    **************************************************
    
    Get_API()

    Purpose:    Get Tenable SC API access and secret

    Input:      $ResourceID        -   The resource ID for the API user in PMP
                $AccessKey         -   Tenable SC API access key
                $SecretKey         -   Tenable SC API secret key
              
    Output:     NONE

    **************************************************
#>
function Get_API($ResourceID, [ref]$AccessKey, [ref]$SecretKey)
{

    Write-Host "Fetching resource" $ResourceID
    
    $pmpToken = Get-Content "$pmpToken" | ConvertTo-SecureString     
    $pmpToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pmpToken))            
    $Header = @{"AUTHTOKEN"=$($pmpToken)}
        
    $BaseUrl="https://$($PMPServer):7272/restapi/json/v1/resources"

    $Url = "$($BaseUrl)?AUTHTOKEN=$pmpToken"
    $Resource = ((Invoke-WebRequest -uri $Url -UseBasicParsing) | ConvertFrom-Json).operation.Details | Where-Object {$_."RESOURCE NAME" -eq $ResourceID}
    $ResourceId = $Resource."RESOURCE ID"

     $Url = "$BaseUrl/$resourceId/accounts?AUTHTOKEN=$pmpToken"     
     $account = ((Invoke-WebRequest -Uri $Url -UseBasicParsing)  | ConvertFrom-Json).operation.Details."ACCOUNT LIST"

     $passwordId = $account.PASSWDID
     $Url = "$BaseUrl/$resourceId/accounts/$passwordId/password?AUTHTOKEN=$pmpToken"
     $operation = ((Invoke-WebRequest -Uri $Url -UseBasicParsing) | ConvertFrom-Json).operation

    if ($operation.result.status -eq "Success") 
    {
        $Password = $operation.Details.Password
        $Password
    }
    
    $AccessKey.Value = $Account."Account Name"
    $SecretKey.Value = $Password
}


#******************
#Script entry point
#******************

$TransLogFilename = ""
$Device42LogFilename = ""
$TenableSCLogFilename = ""

$AccessKey = ""
$SecretKey = ""

$error.Clear()

$Customers = New-Object System.Collections.ArrayList
$SMEList = New-Object System.Collections.ArrayList

<#
#Tenable SC Assets Lists
$Network = ""  #SC Asset ID 94
$Telecom = ""  #SC Asset ID 93
$PAP = ""      #SC Asset ID 111
$CORPApps = "" #SC Asset ID 112
$InfoSec = ""  #SC Asset ID 58
$Systems = ""  #SC Asset ID 113
$Support = ""  #SC Asset ID 118
$Test = ""     #SC Asset ID 116
$Dim = "" #SC Asset ID 120
$SubSurface = "" #SC Asset ID 119
$SAP = "" #SC Asset ID 122
$Digital = "" #SC Asset ID 121
$FieldOps = "" #SC Asset ID 463
#>

#Load Tenable Assets lists IDs from the file Assets.csv

$AssetsFile = Get-Content .\Assets\Assets.csv

$AssetsLists = @()

for ($iIndex=0; $iIndex -lt $AssetsFile.Length; $iIndex++)
{    
    $Fields = $AssetsFile[$iIndex].split(",")
    $AssetsLists += New-Object -TypeName psobject -Property @{ID = "$($Fields[0])";  AssetGroup = "$($Fields[1])"; Asset = ''}
}

#We create the transaction log file 
$TransLogFilename = GetFilename -Prefix 'D42SCInt'
$TransLogFilename = $PSScriptRoot + '\Logs\Transaction\' + $TransLogFilename

WriteLog -LogString "Starting scripting execution" -LogFilename $TransLogFilename

Switch($Mode)
{
    #*********************
    #Build critical assets list
    #*********************
    "CABaseline"
    {
        #***********************
        #Tenablequeryv4 - Device42 query used only during development
        #Tenablequeryv2 - Device42 query used in production
        #***********************        
        WriteLog -LogString "Scripting running bulk critical asset list update" -LogFilename $TransLogFilename
        
        #GetCritical -Query 'Tenablequeryv4'
        GetCritical -Query 'Tenablequeryv2'
    }
    
    #*********************
    #Update Asset Criticality
    #*********************
    "UpdateCAList"
    {
        WriteLog -LogString "Scripting update Asset Criticality Rating in Tenable SC" -LogFilename $TransLogFilename

        #We create the log file for data from Device42
        $Device42LogFilename = GetFilename -Prefix 'Device42'
        $Device42LogFilename = $PSScriptRoot + '\Logs\Assets\Device42\' + $Device42LogFilename
        WriteLog -LogString "Date,Device_Name,Criticality,IP Addresses" -LogFilename $Device42LogFilename -flgDate $true

        #We create the log file for data from Tenabble SC Plus
        $TenableSCLogFilename = GetFilename -Prefix 'TenableSC'
        $TenableSCLogFilename = $PSScriptRoot + '\Logs\Assets\TenableSC\' + $TenableSCLogFilename
        WriteLog -LogString "Date,NetBios,UUID,IP Address,OS,ACR Overwritten Score,ACR Score" -LogFilename $TenableSCLogFilename -flgDate $true
                
        $Assets = GetCritical -Query 'Tenablequeryv2'

        #Fetching Tenable API key from PMP
        Get_API -ResourceID $SCAPI -AccessKey ([ref]$AccessKey) -SecretKey ([ref]$SecretKey)
        for($iIndex = 1; $iIndex -le $Assets.Count; $iIndex++)
        {            
            WriteLog -LogString "$($Assets[$iIndex].Device_Name),$($Assets[$iIndex].Criticality),$($Assets[$iIndex].all_listener_device_ips)" -LogFilename $Device42LogFilename 
            
            if($Assets[$iIndex].all_listener_device_ips.length -gt 1)
            {
                $IPs = SplitIPList -IPList $Assets[$iIndex].all_listener_device_ips
                if($IPs -eq $null)
                {
                    $IP = $Assets[$iIndex].all_listener_device_ips.Trim()
                }
                elseif($IPs -ne $null)
                {
                    $IP = $IPs[0].Trim()
                }                                   
                SearchHost -HostIP $IP -AccessKey $AccessKey -SecretKey $SecretKey -Critical $Assets[$iIndex].Criticality
            }            
        }                
    }
    #*********************
    #Update assets lists
    #*********************
    "UpdateAssets"
    {
        Get_API -ResourceID 'Device42 Client_key' -AccessKey ([ref]$AccessKey) -SecretKey ([ref]$SecretKey)

        $d42_username = $AccessKey
        $d42_password = $SecretKey

        $Credentials = "$($d42_username):$($d42_password)"
        $AccessToken = GetAccessToken -Credentials $Credentials

        $d42_headers = @{Authorization = "Bearer $AccessToken"
        "Content-Type" = "application/json"}        

        $d42_url = "https://device42/services/data/v1.0/query/?saved_query_name=Tenablequeryv2&delimiter=,&header=yes&output_type=json"
        $result = Invoke-WebRequest -Uri $d42_url -Headers $d42_headers -Method Get
        $json = $result | ConvertFrom-Json

        #*********
        #Debug code
        Write-Output "Device Name = $($json.device_name)"
        Write-Output "Device Customer = $($json.Customer)"
        #*************
        
        #Fetching Tenable API key from PMP
        Get_API -ResourceID $SCAPI -AccessKey ([ref]$AccessKey) -SecretKey ([ref]$SecretKey)

        GetUsers        

        #************
        #Debug code
        #GetAssetsLists -AccessKey $AccessKey -SecretKey $SecretKey
        #************

        for($Index = 0; $Index -lt $json.length; $Index++)
        {
            #************
            #Debug
            #************
            write-host $json[$Index].Environment $json[$Index].Owner $json[$Index].'IP Addresses Discovered' $json[$Index].all_listener_device_ips
            
            WriteLog -LogString "$($json[$Index].Environment) $($json[$Index].Owner) $($json[$Index].'IP Addresses Discovered') $($json[$Index].all_listener_device_ips)" -LogFilename $TransLogFilename

            if((($json[$Index].Environment -eq 'Production') -or ($json[$Index].Environment -eq 'Non-Production')) -and ($json[$Index].'IP Addresses Discovered'-gt 0))
            {
                
                if($json[$Index].Customer.Contains('Systems'))
                {                                        
                    WriteLog -LogString "Customer for $($json[$Index].'all_listener_device_ips') is $($json[$Index].Customer)" -LogFilename $TransLogFilename
                    
                    if(($json[$Index].Owner.length -gt 0) -and ($json[$Index].Owner -eq 'Diyar L3'))
                    {
                        AddIPs -Assets ([ref]$AssetsLists) -IPList $json[$Index].all_listener_device_ips -AssetIndex 5 -IPcount $json[$Index].'IP Addresses Discovered'
                    }
                    
                    if(($json[$Index].Owner.length -gt 0) -and ($json[$Index].Owner -ne 'Diyar L3'))
                    {
                        AddOwnerTwo -Owner $json[$Index].Owner
                    }
                }
                elseif($json[$Index].Customer.Contains('Network'))
                {
                    AddIPs -Assets ([ref]$AssetsLists) -IPList $json[$Index].all_listener_device_ips -AssetIndex 0 -IPcount $json[$Index].'IP Addresses Discovered'
                }
                elseif($json[$Index].Customer.Contains('Support'))
                {
                    AddIPs -Assets ([ref]$AssetsLists) -IPList $json[$Index].all_listener_device_ips -AssetIndex 6 -IPcount $json[$Index].'IP Addresses Discovered'
                }
                elseif($json[$Index].Customer.Contains('Infosec'))
                {
                    AddIPs -Assets ([ref]$AssetsLists) -IPList $json[$Index].all_listener_device_ips -AssetIndex 4 -IPcount $json[$Index].'IP Addresses Discovered'
                }
            }
        }
        
        #Updating the assets in Tenable SC Plus
        for($AssetIndex = 0; $AssetIndex -lt $AssetsLists.Count; $AssetIndex++)
        {        
            if($AssetsLists[$AssetIndex].Asset -ne "")
            {
                UpdateAssetList -AssetID $AssetsLists[$AssetIndex].ID -AccessKey $AccessKey -SecretKey $SecretKey -IPAddrs $AssetsLists[$AssetIndex].Asset
                $AssetsLists[$AssetIndex].Asset.Split(",") | Out-File ".\Assets\$($AssetsLists[$($AssetIndex)].AssetGroup).csv"
            }
        }
    }

    #Get the users from Tenable SC Plus
    "GetUsers"
    {
        GetUsers  
    }        
    
}

WriteLog -LogString "Script terminated" -LogFilename $TransLogFilename