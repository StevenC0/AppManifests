<#PSScriptInfo
.VERSION 1.0
.AUTHOR AndrewTaylor
.DESCRIPTION Creates an Intune application from a Winget Manifest
.GUID 26a6c9e7-d51f-42f6-bd52-555d654b414c
.COMPANYNAME 
.COPYRIGHT GPL
.TAGS intune aad
.LICENSEURI https://github.com/andrew-s-taylor/public/blob/main/LICENSE
.PROJECTURI https://github.com/andrew-s-taylor/public
.ICONURI 
.EXTERNALMODULEDEPENDENCIES powershell-yaml microsoft.graph
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>
<#
.SYNOPSIS
  Creates an Intune application from a Winget Manifest
.DESCRIPTION
Complete end-end creation of application in Intune.
Creates AzureAD group for Install and Uninstall
Extracts information from Winget custom manifest

.INPUTS
Winget YAML URL
.OUTPUTS
None
.NOTES
  Version:        1.0
  Author:         Andrew Taylor
  Twitter:        @AndrewTaylor_2
  WWW:            andrewstaylor.com
  Creation Date:  31/10/2022
  Purpose/Change: Initial script development
  
.EXAMPLE
N/A
#>

####################################################


[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $reponame,
    [Parameter()]
    [String]
    $ownername,
    [Parameter()]
    [String]
    $tenant,
    [Parameter()]
    [String]
    $clientid,
    [Parameter()]
    [String]
    $token,
    [Parameter()]
    [String]
    $clientsecret
)


###############################################################################################################
######                                          Download Apps                                            ######
###############################################################################################################

##Set Download Directory

$directory = $env:TEMP
#Create Temp location
$random = Get-Random -Maximum 1000 
$random = $random.ToString()
$date =get-date -format yyMMddmmss
$date = $date.ToString()
$path2 = $random + "-"  + $date
$path = $directory + "\" + $path2 + "\"
new-item -ItemType Directory -Path $path


##IntuneWinAppUtil
$intuneapputilurl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
$intuneapputiloutput = $path + "IntuneWinAppUtil.exe"
Invoke-WebRequest -Uri $intuneapputilurl -OutFile $intuneapputiloutput


###############################################################################################################
######                                         Install Modules                                           ######
###############################################################################################################
Write-Host "Installing Intune modules if required (current user scope)"

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name powershell-yaml) {
    Write-Host "PowerShell YAML Already Installed"
} 
else {
        Install-Module -Name powershell-yaml -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "PowerShell YAML Installed"
}

Write-Host "Installing Microsoft Graph modules if required (current user scope)"

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.Groups) {
    Write-Host "Microsoft Graph Groups Already Installed "
} 
else {
        Install-Module -Name Microsoft.Graph.Groups -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "Microsoft Graph Groups Installed"
}

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement) {
    Write-Host "Microsoft Graph DeviceManagement Already Installed"
} 
else {
        Install-Module -Name Microsoft.Graph.DeviceManagement -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "Microsoft Graph DeviceManagement Installed"
}

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.Intune) {
    Write-Host "Microsoft Graph Intune Already Installed"
} 
else {
        Install-Module -Name Microsoft.Graph.Intune -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "Microsoft Graph Intune Installed"
}

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
    Write-Host "Microsoft Graph Authentication Already Installed"
} 
else {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "Microsoft Graph Authentication Installed"
}

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name microsoft.graph.devices.corporatemanagement ) {
    Write-Host "Microsoft Graph Corporate Management Already Installed"
} 
else {
        Install-Module -Name microsoft.graph.devices.corporatemanagement  -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "Microsoft Graph Corporate Management Installed"
    }



###############################################################################################################
######                                     Graph Connection                                              ######
###############################################################################################################
##Connect using Secret
$tenantId = $tenant
 
$body = @{
    grant_type="client_credentials";
    client_id=$clientId;
    client_secret=$clientSecret;
    scope="https://graph.microsoft.com/.default";
}
 
$response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token -Body $body
$accessToken = $response.access_token
 
$accessToken

write-host "Importing Modules"
#Importing Modules
Import-Module powershell-yaml
Import-Module microsoft.graph.groups
import-module microsoft.graph.intune
import-module microsoft.graph.devicemanagement
import-module microsoft.graph.authentication
import-module microsoft.graph.devices.corporatemanagement
write-host "Modules Imported"

#Get Creds and connect
#Connect to Graph
write-host "Connecting to Graph"
write-host $body
Select-MgProfile -Name Beta
Connect-MgGraph  -AccessToken $accessToken 
write-host "Graph Connection Established"


###############################################################################################################
######                                          Add Functions                                            ######
###############################################################################################################
function Add-MDMApplication() {

    <#
        .SYNOPSIS
        This function is used to add an MDM application using the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and adds an MDM application from the itunes store
        .EXAMPLE
        Add-MDMApplication -JSON $JSON
        Adds an application into Intune
        .NOTES
        NAME: Add-MDMApplication
        #>
        
    [cmdletbinding()]
        
    param
    (
        $JSON
    )
        
    try {
        
        if (!$JSON) {
        
            Write-Error "No JSON was passed to the function, provide a JSON variable"
            break
        
        }
        
        Test-JSON -JSON $JSON

        New-MgDeviceAppMgtMobileApp -BodyParameter $JSON        
    }
        
    catch {
        
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Debug "Response content:`n$responseBody"
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

        break
        
    }
        
}
        
####################################################
        
Function Add-ApplicationAssignment() {
        
    <#
        .SYNOPSIS
        This function is used to add an application assignment using the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and adds a application assignment
        .EXAMPLE
        Add-ApplicationAssignment -ApplicationId $ApplicationId -TargetGroupId $TargetGroupId -InstallIntent $InstallIntent
        Adds an application assignment in Intune
        .NOTES
        NAME: Add-ApplicationAssignment
        #>
        
    [cmdletbinding()]
        
    param
    (
        $ApplicationId,
        $TargetGroupId,
        $InstallIntent
    )
            
    try {
        
        if (!$ApplicationId) {
        
            Write-Error "No Application Id specified, specify a valid Application Id"
            break
        
        }
        
        if (!$TargetGroupId) {
        
            Write-Error "No Target Group Id specified, specify a valid Target Group Id"
            break
        
        }
        
                
        if (!$InstallIntent) {
        
            Write-Error "No Install Intent specified, specify a valid Install Intent - available, notApplicable, required, uninstall, availableWithoutEnrollment"
            break
        
        }
        
        $JSON = @"
        {
            "mobileAppAssignments": [
            {
                "@odata.type": "#microsoft.graph.mobileAppAssignment",
                "target": {
                "@odata.type": "#microsoft.graph.groupAssignmentTarget",
                "groupId": "$TargetGroupId"
                },
                "intent": "$InstallIntent"
            }
            ]
        }
"@
        New-MgDeviceAppMgtMobileAppAssignment -BodyParameter $JSON
        
    }
            
    catch {
        
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Debug "Response content:`n$responseBody"
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        break
        
    }
        
}
        
        
function CloneObject($object) {
        
    $stream = New-Object IO.MemoryStream
    $formatter = New-Object Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $formatter.Serialize($stream, $object)
    $stream.Position = 0
    $formatter.Deserialize($stream)
}
        
####################################################
        
function UploadAzureStorageChunk($sasUri, $id, $body) {
        
    $uri = "$sasUri&comp=block&blockid=$id"
    $request = "PUT $uri"
        
    $iso = [System.Text.Encoding]::GetEncoding("iso-8859-1")
    $encodedBody = $iso.GetString($body)
    $headers = @{
        "x-ms-blob-type" = "BlockBlob"
    }
        
    if ($logRequestUris) { Write-Verbose $request }
    if ($logHeaders) { WriteHeaders $headers }
        
    try {
        Invoke-WebRequest $uri -Method Put -Headers $headers -Body $encodedBody
    }
    catch {
        Write-Error $request
        Write-Error $_.Exception.Message
        throw
    }
        
}
        
####################################################
        
function FinalizeAzureStorageUpload($sasUri, $ids) {
        
    $uri = "$sasUri&comp=blocklist"
    $request = "PUT $uri"
        
    $xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>'
    foreach ($id in $ids) {
        $xml += "<Latest>$id</Latest>"
    }
    $xml += '</BlockList>'
        
    if ($logRequestUris) { Write-Verbose $request }
    if ($logContent) { Write-Verbose $xml }
        
    try {
        Invoke-RestMethod $uri -Method Put -Body $xml
    }
    catch {
        Write-Error $request
        Write-Error $_.Exception.Message
        throw
    }
}
        
####################################################
        
function UploadFileToAzureStorage($sasUri, $filepath, $fileUri) {
        
    try {
        
        $chunkSizeInBytes = 1024l * 1024l * $azureStorageUploadChunkSizeInMb
                
        # Start the timer for SAS URI renewal.
        $sasRenewalTimer = [System.Diagnostics.Stopwatch]::StartNew()
                
        # Find the file size and open the file.
        $fileSize = (Get-Item $filepath).length
        $chunks = [Math]::Ceiling($fileSize / $chunkSizeInBytes)
        $reader = New-Object System.IO.BinaryReader([System.IO.File]::Open($filepath, [System.IO.FileMode]::Open))
        $reader.BaseStream.Seek(0, [System.IO.SeekOrigin]::Begin)
                
        # Upload each chunk. Check whether a SAS URI renewal is required after each chunk is uploaded and renew if needed.
        $ids = @()
        
        for ($chunk = 0; $chunk -lt $chunks; $chunk++) {
        
            $id = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($chunk.ToString("0000")))
            $ids += $id
        
            $start = $chunk * $chunkSizeInBytes
            $length = [Math]::Min($chunkSizeInBytes, $fileSize - $start)
            $bytes = $reader.ReadBytes($length)
                    
            $currentChunk = $chunk + 1			
        
            Write-Progress -Activity "Uploading File to Azure Storage" -status "Uploading chunk $currentChunk of $chunks" `
                -percentComplete ($currentChunk / $chunks * 100)
        
            UploadAzureStorageChunk $sasUri $id $bytes
                    
            # Renew the SAS URI if 7 minutes have elapsed since the upload started or was renewed last.
            if ($currentChunk -lt $chunks -and $sasRenewalTimer.ElapsedMilliseconds -ge 450000) {
        
                RenewAzureStorageUpload $fileUri
                $sasRenewalTimer.Restart()
                    
            }
        
        }
        
        Write-Progress -Completed -Activity "Uploading File to Azure Storage"
        
        $reader.Close()
        
    }
        
    finally {
        
        if ($null -ne $reader) { $reader.Dispose() }
            
    }
            
    # Finalize the upload.
    FinalizeAzureStorageUpload $sasUri $ids
        
}
        
####################################################
        
function RenewAzureStorageUpload($fileUri) {
        
    $renewalUri = "$fileUri/renewUpload"
    $actionBody = ""
    Invoke-MgGraphRequest -method POST -Uri $renewalUri -Body $actionBody
            
    Start-WaitForFileProcessing $fileUri "AzureStorageUriRenewal" $azureStorageRenewSasUriBackOffTimeInSeconds
        
}
        
####################################################
        
function Start-WaitForFileProcessing($fileUri, $stage) {
    
    $attempts = 600
    $waitTimeInSeconds = 10
        
    $successState = "$($stage)Success"
    $pendingState = "$($stage)Pending"
        
    $file = $null
    while ($attempts -gt 0) {
        $file = Invoke-MgGraphRequest -Method GET -Uri $fileUri
        
        if ($file.uploadState -eq $successState) {
            break
        }
        elseif ($file.uploadState -ne $pendingState) {
            Write-Error $_.Exception.Message
            throw "File upload state is not success: $($file.uploadState)"
        }
        
        Start-Sleep $waitTimeInSeconds
        $attempts--
    }
        
    if ($null -eq $file -or $file.uploadState -ne $successState) {
        throw "File request did not complete in the allotted time."
    }
        
    $file
}
        
####################################################
        
function Get-Win32AppBody() {
        
    param
    (
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI", Position = 1)]
        [Switch]$MSI,
        
        [parameter(Mandatory = $true, ParameterSetName = "EXE", Position = 1)]
        [Switch]$EXE,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$displayName,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$publisher,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$description,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$filename,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SetupFileName,
        
        [parameter(Mandatory = $true)]
        [ValidateSet('system', 'user')]
        $installExperience,
        
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        $installCommandLine,
        
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        $uninstallCommandLine,
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiPackageType,
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiProductCode,
        
        [parameter(Mandatory = $false, ParameterSetName = "MSI")]
        $MsiProductName,
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiProductVersion,
        
        [parameter(Mandatory = $false, ParameterSetName = "MSI")]
        $MsiPublisher,
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiRequiresReboot,
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiUpgradeCode
        
    )
        
    if ($MSI) {
        
        $body = @{ "@odata.type" = "#microsoft.graph.win32LobApp" }
        $body.applicableArchitectures = "x64,x86"
        $body.description = $description
        $body.developer = ""
        $body.displayName = $displayName
        $body.fileName = $filename
        $body.installCommandLine = "msiexec /i `"$SetupFileName`""
        $body.installExperience = @{"runAsAccount" = "$installExperience" }
        $body.informationUrl = $null
        $body.isFeatured = $false
        $body.minimumSupportedOperatingSystem = @{"v10_1607" = $true }
        $body.msiInformation = @{
            "packageType"    = "$MsiPackageType"
            "productCode"    = "$MsiProductCode"
            "productName"    = "$MsiProductName"
            "productVersion" = "$MsiProductVersion"
            "publisher"      = "$MsiPublisher"
            "requiresReboot" = "$MsiRequiresReboot"
            "upgradeCode"    = "$MsiUpgradeCode"
        }
        $body.notes = ""
        $body.owner = ""
        $body.privacyInformationUrl = $null
        $body.publisher = $publisher
        $body.runAs32bit = $false
        $body.setupFilePath = $SetupFileName
        $body.uninstallCommandLine = "msiexec /x `"$MsiProductCode`""
        
    }
        
    elseif ($EXE) {
        
        $body = @{ "@odata.type" = "#microsoft.graph.win32LobApp" }
        $body.description = $description
        $body.developer = ""
        $body.displayName = $displayName
        $body.fileName = $filename
        $body.installCommandLine = "$installCommandLine"
        $body.installExperience = @{"runAsAccount" = "$installExperience" }
        $body.informationUrl = $null
        $body.isFeatured = $false
        $body.minimumSupportedOperatingSystem = @{"v10_1607" = $true }
        $body.msiInformation = $null
        $body.notes = ""
        $body.owner = ""
        $body.privacyInformationUrl = $null
        $body.publisher = $publisher
        $body.runAs32bit = $false
        $body.setupFilePath = $SetupFileName
        $body.uninstallCommandLine = "$uninstallCommandLine"
        
    }
        
    $body
}
        
####################################################
        
function GetAppFileBody($name, $size, $sizeEncrypted, $manifest) {
        
    $body = @{ "@odata.type" = "#microsoft.graph.mobileAppContentFile" }
    $body.name = $name
    $body.size = $size
    $body.sizeEncrypted = $sizeEncrypted
    $body.manifest = $manifest
    $body.isDependency = $false
        
    $body
}
        
####################################################
        
function GetAppCommitBody($contentVersionId, $LobType) {
        
    $body = @{ "@odata.type" = "#$LobType" }
    $body.committedContentVersion = $contentVersionId
        
    $body
        
}
        
####################################################
        
Function Test-SourceFile() {
        
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceFile
    )
        
    try {
        
        if (!(test-path "$SourceFile")) {
        
            Write-Error "Source File '$sourceFile' doesn't exist..."
            throw
        
        }
        
    }
        
    catch {
        
        Write-Error $_.Exception.Message
        break
        
    }
        
}
        
####################################################
        
Function New-DetectionRule() {
        
    [cmdletbinding()]
        
    param
    (
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell", Position = 1)]
        [Switch]$PowerShell,
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI", Position = 1)]
        [Switch]$MSI,
        
        [parameter(Mandatory = $true, ParameterSetName = "File", Position = 1)]
        [Switch]$File,
        
        [parameter(Mandatory = $true, ParameterSetName = "Registry", Position = 1)]
        [Switch]$Registry,
        
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell")]
        [ValidateNotNullOrEmpty()]
        [String]$ScriptFile,
        
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell")]
        [ValidateNotNullOrEmpty()]
        $enforceSignatureCheck,
        
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell")]
        [ValidateNotNullOrEmpty()]
        $runAs32Bit,
        
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        [String]$MSIproductCode,
           
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateNotNullOrEmpty()]
        [String]$Path,
         
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateNotNullOrEmpty()]
        [string]$FileOrFolderName,
        
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateSet("notConfigured", "exists", "modifiedDate", "createdDate", "version", "sizeInMB")]
        [string]$FileDetectionType,
        
        [parameter(Mandatory = $false, ParameterSetName = "File")]
        $FileDetectionValue = $null,
        
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateSet("True", "False")]
        [string]$check32BitOn64System = "False",
        
        [parameter(Mandatory = $true, ParameterSetName = "Registry")]
        [ValidateNotNullOrEmpty()]
        [String]$RegistryKeyPath,
        
        [parameter(Mandatory = $true, ParameterSetName = "Registry")]
        [ValidateSet("notConfigured", "exists", "doesNotExist", "string", "integer", "version")]
        [string]$RegistryDetectionType,
        
        [parameter(Mandatory = $false, ParameterSetName = "Registry")]
        [ValidateNotNullOrEmpty()]
        [String]$RegistryValue,
        
        [parameter(Mandatory = $true, ParameterSetName = "Registry")]
        [ValidateSet("True", "False")]
        [string]$check32BitRegOn64System = "False"
        
    )
        
    if ($PowerShell) {
        
        if (!(Test-Path "$ScriptFile")) {
                    
            Write-Error "Could not find file '$ScriptFile'..."
            Write-Error "Script can't continue..."
            break
        
        }
                
        $ScriptContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$ScriptFile"))
                
        $DR = @{ "@odata.type" = "#microsoft.graph.win32LobAppPowerShellScriptDetection" }
        $DR.enforceSignatureCheck = $false
        $DR.runAs32Bit = $false
        $DR.scriptContent = "$ScriptContent"
        
    }
            
    elseif ($MSI) {
            
        $DR = @{ "@odata.type" = "#microsoft.graph.win32LobAppProductCodeDetection" }
        $DR.productVersionOperator = "notConfigured"
        $DR.productCode = "$MsiProductCode"
        $DR.productVersion = $null
        
    }
        
    elseif ($File) {
            
        $DR = @{ "@odata.type" = "#microsoft.graph.win32LobAppFileSystemDetection" }
        $DR.check32BitOn64System = "$check32BitOn64System"
        $DR.detectionType = "$FileDetectionType"
        $DR.detectionValue = $FileDetectionValue
        $DR.fileOrFolderName = "$FileOrFolderName"
        $DR.operator = "notConfigured"
        $DR.path = "$Path"
        
    }
        
    elseif ($Registry) {
            
        $DR = @{ "@odata.type" = "#microsoft.graph.win32LobAppRegistryDetection" }
        $DR.check32BitOn64System = "$check32BitRegOn64System"
        $DR.detectionType = "$RegistryDetectionType"
        $DR.detectionValue = ""
        $DR.keyPath = "$RegistryKeyPath"
        $DR.operator = "notConfigured"
        $DR.valueName = "$RegistryValue"
        
    }
        
    return $DR
        
}
        
####################################################
        
function Get-DefaultReturnCodes() {
        
    @{"returnCode" = 0; "type" = "success" }, `
    @{"returnCode" = 1707; "type" = "success" }, `
    @{"returnCode" = 3010; "type" = "softReboot" }, `
    @{"returnCode" = 1641; "type" = "hardReboot" }, `
    @{"returnCode" = 1618; "type" = "retry" }
        
}
        
####################################################
        
function New-ReturnCode() {
        
    param
    (
        [parameter(Mandatory = $true)]
        [int]$returnCode,
        [parameter(Mandatory = $true)]
        [ValidateSet('success', 'softReboot', 'hardReboot', 'retry')]
        $type
    )
        
    @{"returnCode" = $returnCode; "type" = "$type" }
        
}
        
####################################################
        
Function Get-IntuneWinXML() {
        
    param
    (
        [Parameter(Mandatory = $true)]
        $SourceFile,
        
        [Parameter(Mandatory = $true)]
        $fileName,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("false", "true")]
        [string]$removeitem = "true"
    )
        
    Test-SourceFile "$SourceFile"
        
    $Directory = [System.IO.Path]::GetDirectoryName("$SourceFile")
        
    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead("$SourceFile")
        
    $zip.Entries | where-object { $_.Name -like "$filename" } | foreach-object {
        
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$Directory\$filename", $true)
        
    }
        
    $zip.Dispose()
        
    [xml]$IntuneWinXML = Get-Content "$Directory\$filename"
        
    return $IntuneWinXML
        
    if ($removeitem -eq "true") { remove-item "$Directory\$filename" }
        
}
        
####################################################
        
Function Get-IntuneWinFile() {
        
    param
    (
        [Parameter(Mandatory = $true)]
        $SourceFile,
        
        [Parameter(Mandatory = $true)]
        $fileName,
        
        [Parameter(Mandatory = $false)]
        [string]$Folder = "win32"
    )
        
    $Directory = [System.IO.Path]::GetDirectoryName("$SourceFile")
        
    if (!(Test-Path "$Directory\$folder")) {
        
        New-Item -ItemType Directory -Path "$Directory" -Name "$folder" | Out-Null
        
    }
        
    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead("$SourceFile")
        
    $zip.Entries | Where-Object { $_.Name -like "$filename" } | ForEach-Object {
        
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$Directory\$folder\$filename", $true)
        
    }
        
    $zip.Dispose()
        
    return "$Directory\$folder\$filename"
        
    if ($removeitem -eq "true") { remove-item "$Directory\$filename" }
        
}
        
####################################################
        
function Invoke-UploadWin32Lob() {
        
    <#
        .SYNOPSIS
        This function is used to upload a Win32 Application to the Intune Service
        .DESCRIPTION
        This function is used to upload a Win32 Application to the Intune Service
        .EXAMPLE
        Invoke-UploadWin32Lob "C:\Packages\package.intunewin" -publisher "Microsoft" -description "Package"
        This example uses all parameters required to add an intunewin File into the Intune Service
        .NOTES
        NAME: Invoke-UploadWin32Lob
        #>
        
    [cmdletbinding()]
        
    param
    (
        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFile,
        
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$displayName,
        
        [parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$publisher,
        
        [parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$description,
        
        [parameter(Mandatory = $true, Position = 4)]
        [ValidateNotNullOrEmpty()]
        $detectionRules,
        
        [parameter(Mandatory = $true, Position = 5)]
        [ValidateNotNullOrEmpty()]
        $returnCodes,
        
        [parameter(Mandatory = $false, Position = 6)]
        [ValidateNotNullOrEmpty()]
        [string]$installCmdLine,
        
        [parameter(Mandatory = $false, Position = 7)]
        [ValidateNotNullOrEmpty()]
        [string]$uninstallCmdLine,
        
        [parameter(Mandatory = $false, Position = 8)]
        [ValidateSet('system', 'user')]
        $installExperience = "system"
    )
        
    try	{
        
        $LOBType = "microsoft.graph.win32LobApp"
        
        Write-Verbose "Testing if SourceFile '$SourceFile' Path is valid..."
        Test-SourceFile "$SourceFile"
                
        Write-Verbose "Creating JSON data to pass to the service..."
        
        # Funciton to read Win32LOB file
        $DetectionXML = Get-IntuneWinXML "$SourceFile" -fileName "detection.xml"
        
        # If displayName input don't use Name from detection.xml file
        if ($displayName) { $DisplayName = $displayName }
        else { $DisplayName = $DetectionXML.ApplicationInfo.Name }
                
        $FileName = $DetectionXML.ApplicationInfo.FileName
        
        $SetupFileName = $DetectionXML.ApplicationInfo.SetupFile
        
        $Ext = [System.IO.Path]::GetExtension($SetupFileName)
        
        if ((($Ext).contains("msi") -or ($Ext).contains("Msi")) -and (!$installCmdLine -or !$uninstallCmdLine)) {
        
            # MSI
            $MsiExecutionContext = $DetectionXML.ApplicationInfo.MsiInfo.MsiExecutionContext
            $MsiPackageType = "DualPurpose"
            if ($MsiExecutionContext -eq "System") { $MsiPackageType = "PerMachine" }
            elseif ($MsiExecutionContext -eq "User") { $MsiPackageType = "PerUser" }
        
            $MsiProductCode = $DetectionXML.ApplicationInfo.MsiInfo.MsiProductCode
            $MsiProductVersion = $DetectionXML.ApplicationInfo.MsiInfo.MsiProductVersion
            $MsiPublisher = $DetectionXML.ApplicationInfo.MsiInfo.MsiPublisher
            $MsiRequiresReboot = $DetectionXML.ApplicationInfo.MsiInfo.MsiRequiresReboot
            $MsiUpgradeCode = $DetectionXML.ApplicationInfo.MsiInfo.MsiUpgradeCode
                    
            if ($MsiRequiresReboot -eq "false") { $MsiRequiresReboot = $false }
            elseif ($MsiRequiresReboot -eq "true") { $MsiRequiresReboot = $true }
        
            $mobileAppBody = Get-Win32AppBody `
                -MSI `
                -displayName "$DisplayName" `
                -publisher "$publisher" `
                -description $description `
                -filename $FileName `
                -SetupFileName "$SetupFileName" `
                -installExperience $installExperience `
                -MsiPackageType $MsiPackageType `
                -MsiProductCode $MsiProductCode `
                -MsiProductName $displayName `
                -MsiProductVersion $MsiProductVersion `
                -MsiPublisher $MsiPublisher `
                -MsiRequiresReboot $MsiRequiresReboot `
                -MsiUpgradeCode $MsiUpgradeCode
        
        }
        
        else {
        
            $mobileAppBody = Get-Win32AppBody -EXE -displayName "$DisplayName" -publisher "$publisher" `
                -description $description -filename $FileName -SetupFileName "$SetupFileName" `
                -installExperience $installExperience -installCommandLine $installCmdLine `
                -uninstallCommandLine $uninstallcmdline
        
        }
        
        if ($DetectionRules.'@odata.type' -contains "#microsoft.graph.win32LobAppPowerShellScriptDetection" -and @($DetectionRules).'@odata.type'.Count -gt 1) {
        
            Write-Warning "A Detection Rule can either be 'Manually configure detection rules' or 'Use a custom detection script'"
            Write-Warning "It can't include both..."
            break
        
        }
        
        else {
        
            $mobileAppBody | Add-Member -MemberType NoteProperty -Name 'detectionRules' -Value $detectionRules
        
        }
        
        #ReturnCodes
        
        if ($returnCodes) {
                
            $mobileAppBody | Add-Member -MemberType NoteProperty -Name 'returnCodes' -Value @($returnCodes)
        
        }
        
        else {
            Write-Warning "Intunewin file requires ReturnCodes to be specified"
            Write-Warning "If you want to use the default ReturnCode run 'Get-DefaultReturnCodes'"
            break
        }
        
        Write-Verbose "Creating application in Intune..."
        $mobileApp = New-MgDeviceAppMgtMobileApp -BodyParameter ($mobileAppBody | ConvertTo-Json)
        
        # Get the content version for the new app (this will always be 1 until the new app is committed).
        Write-Verbose "Creating Content Version in the service for the application..."
        $appId = $mobileApp.id
        $contentVersionUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/$LOBType/contentVersions"
        $contentVersion = Invoke-MgGraphRequest -method POST -Uri $contentVersionUri -Body "{}"
        
        # Encrypt file and Get File Information
        Write-Verbose "Getting Encryption Information for '$SourceFile'..."
        
        $encryptionInfo = @{}
        $encryptionInfo.encryptionKey = $DetectionXML.ApplicationInfo.EncryptionInfo.EncryptionKey
        $encryptionInfo.macKey = $DetectionXML.ApplicationInfo.EncryptionInfo.macKey
        $encryptionInfo.initializationVector = $DetectionXML.ApplicationInfo.EncryptionInfo.initializationVector
        $encryptionInfo.mac = $DetectionXML.ApplicationInfo.EncryptionInfo.mac
        $encryptionInfo.profileIdentifier = "ProfileVersion1"
        $encryptionInfo.fileDigest = $DetectionXML.ApplicationInfo.EncryptionInfo.fileDigest
        $encryptionInfo.fileDigestAlgorithm = $DetectionXML.ApplicationInfo.EncryptionInfo.fileDigestAlgorithm
        
        $fileEncryptionInfo = @{}
        $fileEncryptionInfo.fileEncryptionInfo = $encryptionInfo
        
        # Extracting encrypted file
        $IntuneWinFile = Get-IntuneWinFile "$SourceFile" -fileName "$filename"
        
        [int64]$Size = $DetectionXML.ApplicationInfo.UnencryptedContentSize
        $EncrySize = (Get-Item "$IntuneWinFile").Length
        
        # Create a new file for the app.
        Write-Verbose "Creating a new file entry in Azure for the upload..."
        $contentVersionId = $contentVersion.id
        $fileBody = GetAppFileBody "$FileName" $Size $EncrySize $null
        $filesUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files"
        $file = Invoke-MgGraphRequest -Method POST -Uri $filesUri -Body ($fileBody | ConvertTo-Json)
            
        # Wait for the service to process the new file request.
        Write-Verbose "Waiting for the file entry URI to be created..."
        $fileId = $file.id
        $fileUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files/$fileId"
        $file = Start-WaitForFileProcessing $fileUri "AzureStorageUriRequest"
        
        # Upload the content to Azure Storage.
        Write-Verbose "Uploading file to Azure Storage..."
        
        UploadFileToAzureStorage $file.azureStorageUri "$IntuneWinFile" $fileUri
        
        # Need to Add removal of IntuneWin file
        Remove-Item "$IntuneWinFile" -Force
        
        # Commit the file.
        Write-Verbose "Committing the file into Azure Storage..."
        $commitFileUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files/$fileId/commit"
        Invoke-MgGraphRequest -Uri $commitFileUri -Method POST -Body ($fileEncryptionInfo | ConvertTo-Json)
        
        # Wait for the service to process the commit file request.
        Write-Verbose "Waiting for the service to process the commit file request..."
        $file = Start-WaitForFileProcessing $fileUri "CommitFile"
        
        # Commit the app.
        Write-Verbose "Committing the file into Azure Storage..."
        $commitAppUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId"
        $commitAppBody = GetAppCommitBody $contentVersionId $LOBType
        Invoke-MgGraphRequest -Method PATCH -Uri $commitAppUri -Body ($commitAppBody | ConvertTo-Json)
        
        foreach ($i in 0..$sleep) {
            Write-Progress -Activity "Sleeping for $($sleep-$i) seconds" -PercentComplete ($i / $sleep * 100) -SecondsRemaining ($sleep - $i)
            Start-Sleep -s 1
        }            
    }
            
    catch {
        Write-Error "Aborting with exception: $($_.Exception.ToString())"
            
    }
}
        
$logRequestUris = $true
$logHeaders = $false
$logContent = $true
        
$azureStorageUploadChunkSizeInMb = 6l
        
$sleep = 30
        
Function Get-IntuneApplication() {
        
    <#
        .SYNOPSIS
        This function is used to get applications from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets any applications added
        .EXAMPLE
        Get-IntuneApplication
        Returns any applications configured in Intune
        .NOTES
        NAME: Get-IntuneApplication
        #>            
    try {

        return Get-MgDeviceAppMgtMobileApp -All | Where-Object { (!($_.AdditionalProperties['@odata.type']).Contains("managed")) }
        
    }
            
    catch {
        
        $ex = $_.Exception
        Write-Verbose "Request to $Uri failed with HTTP Status $([int]$ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Verbose "Response content:`n$responseBody"
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        break
        
    }
        
}
        
Function Find-WinGetPackage {
    <#
        .SYNOPSIS
        Searches for a package on configured sources. 
        Additional options can be provided to filter the output, much like the search command.
        
        .DESCRIPTION
        By running this cmdlet with the required inputs, it will retrieve the packages installed on the local system.
        .PARAMETER Filter
        Used to search across multiple fields of the package.
        
        .PARAMETER Id
        Used to specify the Id of the package
        .PARAMETER Name
        Used to specify the Name of the package
        .PARAMETER Moniker
        Used to specify the Moniker of the package
        .PARAMETER Tag
        Used to specify the Tag of the package
        
        .PARAMETER Command
        Used to specify the Command of the package
        
        .PARAMETER Exact
        Used to specify an exact match for any parameters provided. Many of the other parameters may be used for case insensitive substring matches if Exact is not specified.
        .PARAMETER Source
        Name of the Windows Package Manager private source. Can be identified by running: "Get-WinGetSource" and using the source Name
        .PARAMETER Count
        Used to specify the maximum number of packages to return
        .PARAMETER Header
        Used to specify the value to pass as the "Windows-Package-Manager" HTTP header for a REST source.
        .PARAMETER VerboseLog
        Used to provide verbose logging for the Windows Package Manager.
        
        .PARAMETER AcceptSourceAgreement
        Used to accept any source agreement required for the source.
        .EXAMPLE
        Find-WinGetPackage -id "Publisher.Package"
        This example searches for a package containing "Publisher.Package" as a valid identifier on all configured sources.
        .EXAMPLE
        Find-WinGetPackage -id "Publisher.Package" -source "Private"
        This example searches for a package containing "Publisher.Package" as a valid identifier from the source named "Private".
        .EXAMPLE
        Find-WinGetPackage -Name "Package"
        This example searches for a package containing "Package" as a valid name on all configured sources.
    #>
    PARAM(
        [Parameter(Position = 0)] $Filter,
        [Parameter()]           $Id,
        [Parameter()]           $Name,
        [Parameter()]           $Moniker,
        [Parameter()]           $Tag,
        [Parameter()]           $Command,
        [Parameter()] [switch]  $Exact,
        [Parameter()]           $Source,
        [Parameter()] [ValidateRange(1, [int]::maxvalue)][int]$Count,
        [Parameter()] [ValidateLength(1, 1024)]$Header,
        [Parameter()] [switch]  $VerboseLog,
        [Parameter()] [switch]  $AcceptSourceAgreement
    )
    BEGIN {
        [string[]]          $WinGetArgs = @("Search")
        [WinGetPackage[]]   $Result = @()
        [string[]]          $IndexTitles = @("Name", "Id", "Version", "Available", "Source")

        if ($PSBoundParameters.ContainsKey('Filter')) {
            ## Search across Name, ID, moniker, and tags
            $WinGetArgs += $Filter
        }
        if ($PSBoundParameters.ContainsKey('Id')) {
            ## Search for the ID
            $WinGetArgs += "--Id", $Id.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Name')) {
            ## Search for the Name
            $WinGetArgs += "--Name", $Name.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Moniker')) {
            ## Search for the Moniker
            $WinGetArgs += "--Moniker", $Moniker.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Tag')) {
            ## Search for the Tag
            $WinGetArgs += "--Tag", $Tag.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Command')) {
            ## Search for the Moniker
            $WinGetArgs += "--Command", $Command.Replace("…", "")
        }
        if ($Exact) {
            ## Search using exact values specified (case sensitive)
            $WinGetArgs += "--Exact"
        }
        if ($PSBoundParameters.ContainsKey('Source')) {
            ## Search for the Source
            $WinGetArgs += "--Source", $Source.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Count')) {
            ## Specify the number of results to return
            $WinGetArgs += "--Count", $Count
        }
        if ($PSBoundParameters.ContainsKey('Header')) {
            ## Pass the value specified as the Windows-Package-Manager HTTP header
            $WinGetArgs += "--header", $Header
        }
        if ($PSBoundParameters.ContainsKey('VerboseLog')) {
            ## Search using exact values specified (case sensitive)
            $WinGetArgs += "--VerboseLog", $VerboseLog
        }
        if ($AcceptSourceAgreement) {
            ## Accept source agreements
            $WinGetArgs += "--accept-source-agreements"
        }
    }
    PROCESS {
        $List = Invoke-WinGetCommand -WinGetArgs $WinGetArgs -IndexTitles $IndexTitles
    
        foreach ($Obj in $List) {
            $Result += [WinGetPackage]::New($Obj) 
        }
    }
    END {
        return $Result
    }
}


Function Install-WinGetPackage {
    <#
        .SYNOPSIS
        Installs a package on the local system. 
        Additional options can be provided to filter the output, much like the search command.
        
        .DESCRIPTION
        By running this cmdlet with the required inputs, it will retrieve the packages installed on the local system.
        .PARAMETER Filter
        Used to search across multiple fields of the package.
        
        .PARAMETER Id
        Used to specify the Id of the package
        .PARAMETER Name
        Used to specify the Name of the package
        .PARAMETER Moniker
        Used to specify the Moniker of the package
        .PARAMETER Tag
        Used to specify the Tag of the package
        
        .PARAMETER Command
        Used to specify the Command of the package
        .PARAMETER Scope
        Used to specify install scope (user or machine)
        
        .PARAMETER Exact
        Used to specify an exact match for any parameters provided. Many of the other parameters may be used for case insensitive substring matches if Exact is not specified.
        .PARAMETER Source
        Name of the Windows Package Manager private source. Can be identified by running: "Get-WinGetSource" and using the source Name
        .PARAMETER Interactive
        Used to specify the installer should be run in interactive mode.
        .PARAMETER Silent
        Used to specify the installer should be run in silent mode with no user input.
        .PARAMETER Locale
        Used to specify the locale for localized package installer.
        .PARAMETER Log
        Used to specify the location for the log location if it is supported by the package installer.
        .PARAMETER Header
        Used to specify the value to pass as the "Windows-Package-Manager" HTTP header for a REST source.
        .PARAMETER Version
        Used to specify the Version of the package
        .PARAMETER VerboseLog
        Used to provide verbose logging for the Windows Package Manager.
        
        .PARAMETER AcceptPackageAgreement
        Used to accept any package agreement required for the package.
        
        .PARAMETER AcceptSourceAgreement
        Used to explicitly accept any agreement required by the source.
        .PARAMETER Local
        Used to install from a local manifest
        .EXAMPLE
        Install-WinGetPackage -id "Publisher.Package"
        This example expects only a single package containing "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Install-WinGetPackage -id "Publisher.Package" -source "Private"
        This example expects the source named "Private" contains a package with "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Install-WinGetPackage -Name "Package"
        This example expects a configured source contains a package with "Package" as a valid name.
    #>

    PARAM(
        [Parameter(Position = 0)] $Filter,
        [Parameter()]           $Name,
        [Parameter()]           $Id,
        [Parameter()]           $Moniker,
        [Parameter()]           $Source,
        [Parameter()] [ValidateSet("User", "Machine")] $Scope,
        [Parameter()] [switch]  $Interactive,
        [Parameter()] [switch]  $Silent,
        [Parameter()] [string]  $Version,
        [Parameter()] [switch]  $Exact,
        [Parameter()] [switch]  $Override,
        [Parameter()] [System.IO.FileInfo]  $Location,
        [Parameter()] [switch]  $Force,
        [Parameter()] [ValidatePattern("^([a-zA-Z]{2,3}|[iI]-[a-zA-Z]+|[xX]-[a-zA-Z]{1,8})(-[a-zA-Z]{1,8})*$")] [string] $Locale,
        [Parameter()] [System.IO.FileInfo]  $Log, ## This is a path of where to create a log.
        [Parameter()] [switch]  $AcceptSourceAgreements,
        [Parameter()] [switch]  $Local # This is for installing local manifests
    )
    BEGIN {
        $WinGetFindArgs = @{}
        [string[]] $WinGetInstallArgs = "Install"
        IF ($PSBoundParameters.ContainsKey('Filter')) {
            IF ($Local) {
                $WinGetInstallArgs += "--Manifest"
            }
            $WinGetInstallArgs += $Filter
        }
        IF ($PSBoundParameters.ContainsKey('Filter')) {
            IF ($Local) {
                $WinGetInstallArgs += "--Manifest"
            }
            $WinGetInstallArgs += $Filter
            $WinGetFindArgs.Add('Filter', $Filter)
        }
        IF ($PSBoundParameters.ContainsKey('Name')) {
            $WinGetInstallArgs += "--Name", $Name
            $WinGetFindArgs.Add('Name', $Name)
        }
        IF ($PSBoundParameters.ContainsKey('Id')) {
            $WinGetInstallArgs += "--Id", $Id
            $WinGetFindArgs.Add('Id', $Id)
        }
        IF ($PSBoundParameters.ContainsKey('Moniker')) {
            $WinGetInstallArgs += "--Moniker", $Moniker
            $WinGetFindArgs.Add('Moniker', $Moniker)
        }
        IF ($PSBoundParameters.ContainsKey('Source')) {
            $WinGetInstallArgs += "--Source", $Source
            $WinGetFindArgs.Add('Source', $Source)
        }
        IF ($PSBoundParameters.ContainsKey('Scope')) {
            $WinGetInstallArgs += "--Scope", $Scope
        }
        IF ($Interactive) {
            $WinGetInstallArgs += "--Interactive"
        }
        IF ($Silent) {
            $WinGetInstallArgs += "--Silent"
        }
        IF ($PSBoundParameters.ContainsKey('Locale')) {
            $WinGetInstallArgs += "--locale", $Locale
        }
        if ($PSBoundParameters.ContainsKey('Version')) {
            $WinGetInstallArgs += "--Version", $Version
        }
        if ($Exact) {
            $WinGetInstallArgs += "--Exact"
            $WinGetFindArgs.Add('Exact', $true)
        }
        if ($PSBoundParameters.ContainsKey('Log')) {
            $WinGetInstallArgs += "--Log", $Log
        }
        if ($PSBoundParameters.ContainsKey('Override')) {
            $WinGetInstallArgs += "--override", $Override
        }
        if ($PSBoundParameters.ContainsKey('Location')) {
            $WinGetInstallArgs += "--Location", $Location
        }
        if ($Force) {
            $WinGetInstallArgs += "--Force"
        }
    }
    PROCESS {
        ## Exact, ID and Source - Talk with Demitrius tomorrow to better understand this.
        IF (!$Local) {
            $Result = Find-WinGetPackage @WinGetFindArgs
        }

        if ($Result.count -eq 1 -or $Local) {
            & "WinGet" $WinGetInstallArgs
            $Result = ""
        }
        elseif ($Result.count -lt 1) {
            Write-Error "Unable to locate package for installation"
            $Result = ""
        }
        else {
            Write-Error "Multiple packages found matching input criteria. Please refine the input."
        }
    }
    END {
        return $Result
    }
}

filter Assert-WhiteSpaceIsNull {
    IF ([string]::IsNullOrWhiteSpace($_)) { $null }
    ELSE { $_ }
}

class WinGetSource {
    [string] $Name
    [string] $Argument
    [string] $Data
    [string] $Identifier
    [string] $Type

    WinGetSource ()
    {  }

    WinGetSource ([string]$a, [string]$b, [string]$c, [string]$d, [string]$e) {
        $this.Name = $a.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Argument = $b.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Data = $c.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Identifier = $d.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Type = $e.TrimEnd() | Assert-WhiteSpaceIsNull
    }

    WinGetSource ([string[]]$a) {
        $this.name = $a[0].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Argument = $a[1].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Data = $a[2].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Identifier = $a[3].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Type = $a[4].TrimEnd() | Assert-WhiteSpaceIsNull
    }
    
    WinGetSource ([WinGetSource]$a) {
        $this.Name = $a.Name.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Argument = $a.Argument.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Data = $a.Data.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Identifier = $a.Identifier.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Type = $a.Type.TrimEnd() | Assert-WhiteSpaceIsNull

    }
    
    [WinGetSource[]] Add ([WinGetSource]$a) {
        $FirstValue = [WinGetSource]::New($this)
        $SecondValue = [WinGetSource]::New($a)
        
        [WinGetSource[]] $Combined = @([WinGetSource]::New($FirstValue), [WinGetSource]::New($SecondValue))

        Return $Combined
    }

    [WinGetSource[]] Add ([String[]]$a) {
        $FirstValue = [WinGetSource]::New($this)
        $SecondValue = [WinGetSource]::New($a)
        
        [WinGetSource[]] $Combined = @([WinGetSource]::New($FirstValue), [WinGetSource]::New($SecondValue))

        Return $Combined
    }
}

class WinGetPackage {
    [string]$Name
    [string]$Id
    [string]$Version
    [string]$Available
    [string]$Source
    [string]$Match

    WinGetPackage ([string] $a, [string]$b, [string]$c, [string]$d, [string]$e) {
        $this.Name = $a.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Id = $b.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Version = $c.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Available = $d.TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Source = $e.TrimEnd() | Assert-WhiteSpaceIsNull
    }
    
    WinGetPackage ([WinGetPackage] $a) {
        $this.Name = $a.Name | Assert-WhiteSpaceIsNull
        $this.Id = $a.Id | Assert-WhiteSpaceIsNull
        $this.Version = $a.Version | Assert-WhiteSpaceIsNull
        $this.Available = $a.Available | Assert-WhiteSpaceIsNull
        $this.Source = $a.Source | Assert-WhiteSpaceIsNull

    }
    WinGetPackage ([psobject] $a) {
        $this.Name = $a.Name | Assert-WhiteSpaceIsNull
        $this.Id = $a.Id | Assert-WhiteSpaceIsNull
        $this.Version = $a.Version | Assert-WhiteSpaceIsNull
        $this.Available = $a.Available | Assert-WhiteSpaceIsNull
        $this.Source = $a.Source | Assert-WhiteSpaceIsNull
    }
    
    WinGetSource ([string[]]$a) {
        $this.name = $a[0].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Id = $a[1].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Version = $a[2].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Available = $a[3].TrimEnd() | Assert-WhiteSpaceIsNull
        $this.Source = $a[4].TrimEnd() | Assert-WhiteSpaceIsNull
    }

    
    [WinGetPackage[]] Add ([WinGetPackage] $a) {
        $FirstValue = [WinGetPackage]::New($this)
        $SecondValue = [WinGetPackage]::New($a)

        [WinGetPackage[]]$Result = @([WinGetPackage]::New($FirstValue), [WinGetPackage]::New($SecondValue))

        Return $Result
    }

    [WinGetPackage[]] Add ([String[]]$a) {
        $FirstValue = [WinGetPackage]::New($this)
        $SecondValue = [WinGetPackage]::New($a)
        
        [WinGetPackage[]] $Combined = @([WinGetPackage]::New($FirstValue), [WinGetPackage]::New($SecondValue))

        Return $Combined
    }
}
Function Invoke-WinGetCommand {
    PARAM(
        [Parameter(Position = 0, Mandatory = $true)] [string[]]$WinGetArgs,
        [Parameter(Position = 0, Mandatory = $true)] [string[]]$IndexTitles,
        [Parameter()]                            [switch] $JSON
    )
    BEGIN {
        $Index = @()
        $Result = @()
        $i = 0
        $IndexTitlesCount = $IndexTitles.Count
        $Offset = 0
        $Found = $false
        
        ## Remove two characters from the string length and add "..." to the end (only if there is the three below characters present).
        [string[]]$WinGetSourceListRaw = & "WinGet" $WingetArgs | out-string -stream | foreach-object { $_ -replace ("$([char]915)$([char]199)$([char]170)", "$([char]199)") }
    }
    PROCESS {
        if ($JSON) {
            ## If expecting JSON content, return the object
            return $WinGetSourceListRaw | ConvertFrom-Json
        }

        ## Gets the indexing of each title
        $rgex = $IndexTitles -join "|"
        for ($Offset = 0; $Offset -lt $WinGetSourceListRaw.Length; $Offset++) {
            if ($WinGetSourceListRaw[$Offset].Split(" ")[0].Trim() -match $rgex) {
                $Found = $true
                break
            }
        }
        if (!$Found) {
            Write-Error -Message "No results were found." -TargetObject $WinGetSourceListRaw
            return
        }
        
        foreach ($IndexTitle in $IndexTitles) {
            ## Creates an array of titles and their string location
            $IndexStart = $WinGetSourceListRaw[$Offset].IndexOf($IndexTitle)
            $IndexEnds = ""

            IF ($IndexStart -ne "-1") {
                $Index += [pscustomobject]@{
                    Title = $IndexTitle
                    Start = $IndexStart
                    Ends  = $IndexEnds
                }
            }
        }

        ## Orders the Object based on Index value
        $Index = $Index | Sort-Object Start

        ## Sets the end of string value
        while ($i -lt $IndexTitlesCount) {
            $i ++

            ## Sets the End of string value (if not null)
            if ($Index[$i].Start) {
                $Index[$i - 1].Ends = ($Index[$i].Start - 1) - $Index[$i - 1].Start 
            }
        }

        ## Builds the WinGetSource Object with contents
        $i = $Offset + 2
        while ($i -lt $WinGetSourceListRaw.Length) {
            $row = $WinGetSourceListRaw[$i]
            try {
                [bool] $TestNotTitles = $WinGetSourceListRaw[0] -ne $row
                [bool] $TestNotHyphenLine = $WinGetSourceListRaw[1] -ne $row -and !$Row.Contains("---")
                [bool] $TestNotNoResults = $row -ne "No package found matching input criteria."
            }
            catch { Wait-Debugger }

            if (!$TestNotNoResults) {
                Write-LogEntry -LogEntry "No package found matching input criteria." -Severity 1
            }

            ## If this is the first pass containing titles or the table line, skip.
            if ($TestNotTitles -and $TestNotHyphenLine -and $TestNotNoResults) {
                $List = @{}

                foreach ($item in $Index) {
                    if ($Item.Ends) {
                        $List[$Item.Title] = $row.SubString($item.Start, $Item.Ends)
                    }
                    else {
                        $List[$item.Title] = $row.SubString($item.Start, $row.Length - $Item.Start)
                    }
                }

                $result += [pscustomobject]$list
            }
            $i++
        }
    }
    END {
        return $Result
    }
}


Function Uninstall-WinGetPackage {
    <#
        .SYNOPSIS
        Uninstalls a package from the local system. 
        Additional options can be provided to filter the output, much like the search command.
        
        .DESCRIPTION
        By running this cmdlet with the required inputs, it will uninstall a package installed on the local system.
        .PARAMETER Filter
        Used to search across multiple fields of the package.
        
        .PARAMETER Id
        Used to specify the Id of the package
        .PARAMETER Name
        Used to specify the Name of the package
        .PARAMETER Moniker
        Used to specify the Moniker of the package
        .PARAMETER Version
        Used to specify the Version of the package
        
        .PARAMETER Exact
        Used to specify an exact match for any parameters provided. Many of the other parameters may be used for case insensitive substring matches if Exact is not specified.
        .PARAMETER Source
        Name of the Windows Package Manager private source. Can be identified by running: "Get-WinGetSource" and using the source Name
        .PARAMETER Interactive
        Used to specify the uninstaller should be run in interactive mode.
        .PARAMETER Silent
        Used to specify the uninstaller should be run in silent mode with no user input.
        .PARAMETER Log
        Used to specify the location for the log location if it is supported by the package uninstaller.
        .PARAMETER VerboseLog
        Used to provide verbose logging for the Windows Package Manager.
        .PARAMETER Header
        Used to specify the value to pass as the "Windows-Package-Manager" HTTP header for a REST source.
        
        .PARAMETER AcceptSourceAgreement
        Used to explicitly accept any agreement required by the source.
        .PARAMETER Local
        Used to uninstall from a local manifest
        .EXAMPLE
        Uninstall-WinGetPackage -id "Publisher.Package"
        This example expects only a single configured REST source with a package containing "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Uninstall-WinGetPackage -id "Publisher.Package" -source "Private"
        This example expects the REST source named "Private" with a package containing "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Uninstall-WinGetPackage -Name "Package"
        This example expects a configured source contains a package with "Package" as a valid name.
    #>

    PARAM(
        [Parameter(Position = 0)] $Filter,
        [Parameter()]           $Name,
        [Parameter()]           $Id,
        [Parameter()]           $Moniker,
        [Parameter()]           $Source,
        [Parameter()] [switch]  $Interactive,
        [Parameter()] [switch]  $Silent,
        [Parameter()] [string]  $Version,
        [Parameter()] [switch]  $Exact,
        [Parameter()] [switch]  $Override,
        [Parameter()] [System.IO.FileInfo]  $Location,
        [Parameter()] [switch]  $Force,
        [Parameter()] [System.IO.FileInfo]  $Log, ## This is a path of where to create a log.
        [Parameter()] [switch]  $AcceptSourceAgreements,
        [Parameter()] [switch]  $Local # This is for installing local manifests
    )
    BEGIN {
        [string[]] $WinGetArgs = "Uninstall"
        IF ($PSBoundParameters.ContainsKey('Filter')) {
            IF ($Local) {
                $WinGetArgs += "--Manifest"
            }
            $WinGetArgs += $Filter
        }
        IF ($PSBoundParameters.ContainsKey('Name')) {
            $WinGetArgs += "--Name", $Name
        }
        IF ($PSBoundParameters.ContainsKey('Id')) {
            $WinGetArgs += "--Id", $Id
        }
        IF ($PSBoundParameters.ContainsKey('Moniker')) {
            $WinGetArgs += "--Moniker", $Moniker
        }
        IF ($PSBoundParameters.ContainsKey('Source')) {
            $WinGetArgs += "--Source", $Source
        }
        IF ($Interactive) {
            $WinGetArgs += "--Interactive"
        }
        IF ($Silent) {
            $WinGetArgs += "--Silent"
        }
        if ($PSBoundParameters.ContainsKey('Version')) {
            $WinGetArgs += "--Version", $Version
        }
        if ($Exact) {
            $WinGetArgs += "--Exact"
        }
        if ($PSBoundParameters.ContainsKey('Log')) {
            $WinGetArgs += "--Log", $Log
        }
        if ($PSBoundParameters.ContainsKey('Location')) {
            $WinGetArgs += "--Location", $Location
        }
        if ($Force) {
            $WinGetArgs += "--Force"
        }
    }
    PROCESS {
        ## Exact, ID and Source - Talk with tomorrow to better understand this.
        IF (!$Local) {
            $Result = Find-WinGetPackage -Filter $Filter -Name $Name -Id $Id -Moniker $Moniker -Tag $Tag -Command $Command -Source $Source
        }

        if ($Result.count -eq 1 -or $Local) {
            & "WinGet" $WingetArgs
            $Result = ""
        }
        elseif ($Result.count -lt 1) {
            Write-Error "Unable to locate package for uninstallation"
            $Result = ""
        }
        else {
            Write-Error "Multiple packages found matching input criteria. Please refine the input."
        }
    }
    END {
        return $Result
    }
}


Function Update-WinGetPackage {
    <#
        .SYNOPSIS
        Upgrades a package on the local system. 
        Additional options can be provided to filter the output, much like the search command.
        
        .DESCRIPTION
        By running this cmdlet with the required inputs, it will retrieve the packages installed on the local system.
        .PARAMETER Filter
        Used to search across multiple fields of the package.
        
        .PARAMETER Id
        Used to specify the Id of the package
        .PARAMETER Name
        Used to specify the Name of the package
        .PARAMETER Moniker
        Used to specify the Moniker of the package
        .PARAMETER Tag
        Used to specify the Tag of the package
        
        .PARAMETER Command
        Used to specify the Command of the package
        .PARAMETER Channel
        Used to specify the channel of the package. Note this is not yet implemented in Windows Package Manager as of version 1.1.0.
        .PARAMETER Scope
        Used to specify install scope (user or machine)
        
        .PARAMETER Exact
        Used to specify an exact match for any parameters provided. Many of the other parameters may be used for case insensitive substring matches if Exact is not specified.
        .PARAMETER Source
        Name of the Windows Package Manager private source. Can be identified by running: "Get-WinGetSource" and using the source Name
        .PARAMETER Manifest
        Path to the manifest on the local file system. Requires local manifest setting to be enabled.
        .PARAMETER Interactive
        Used to specify the installer should be run in interactive mode.
        .PARAMETER Silent
        Used to specify the installer should be run in silent mode with no user input.
        .PARAMETER Locale
        Used to specify the locale for localized package installer.
        .PARAMETER Log
        Used to specify the location for the log location if it is supported by the package installer.
        .PARAMETER Override
        Used to override switches passed to installer.
        .PARAMETER Force
        Used to force the upgrade when the Windows Package Manager would ordinarily not upgrade the package.
        .PARAMETER Location
        Used to specify the location for the package to be upgraded.
        .PARAMETER Header
        Used to specify the value to pass as the "Windows-Package-Manager" HTTP header for a REST source.
        .PARAMETER Version
        Used to specify the Version of the package
        .PARAMETER VerboseLog
        Used to provide verbose logging for the Windows Package Manager.
        
        .PARAMETER AcceptPackageAgreement
        Used to accept any source package required for the package.
        .PARAMETER AcceptSourceAgreement
        .EXAMPLE
        Update-WinGetPackage -id "Publisher.Package"
        This example expects only a single package containing "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Update-WinGetPackage -id "Publisher.Package" -source "Private"
        This example expects the source named "Private" contains a package with "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Update-WinGetPackage -Name "Package"
        This example expects the source named "Private" contains a package with "Package" as a valid name.
    #>

    PARAM(
        [Parameter(Position = 0)] $Filter,
        [Parameter()]           $Name,
        [Parameter()]           $Id,
        [Parameter()]           $Moniker,
        [Parameter()]           $Source,
        [Parameter()] [ValidateSet("User", "Machine")] $Scope,
        [Parameter()] [switch]  $Interactive,
        [Parameter()] [switch]  $Silent,
        [Parameter()] [string]  $Version,
        [Parameter()] [switch]  $Exact,
        [Parameter()] [switch]  $Override,
        [Parameter()] [System.IO.FileInfo]  $Location,
        [Parameter()] [switch]  $Force,
        [Parameter()] [ValidatePattern("^([a-zA-Z]{2,3}|[iI]-[a-zA-Z]+|[xX]-[a-zA-Z]{1,8})(-[a-zA-Z]{1,8})*$")] [string] $Locale,
        [Parameter()] [System.IO.FileInfo]  $Log, ## This is a path of where to create a log.
        [Parameter()] [switch]  $AcceptSourceAgreements
    )
    BEGIN {
        [string[]] $WinGetArgs = "Install"
        IF ($PSBoundParameters.ContainsKey('Filter')) {
            $WinGetArgs += $Filter
        }
        IF ($PSBoundParameters.ContainsKey('Name')) {
            $WinGetArgs += "--Name", $Name
        }
        IF ($PSBoundParameters.ContainsKey('Id')) {
            $WinGetArgs += "--Id", $Id
        }
        IF ($PSBoundParameters.ContainsKey('Moniker')) {
            $WinGetArgs += "--Moniker", $Moniker
        }
        IF ($PSBoundParameters.ContainsKey('Source')) {
            $WinGetArgs += "--Source", $Source
        }
        IF ($PSBoundParameters.ContainsKey('Scope')) {
            $WinGetArgs += "--Scope", $Scope
        }
        IF ($Interactive) {
            $WinGetArgs += "--Interactive"
        }
        IF ($Silent) {
            $WinGetArgs += "--Silent"
        }
        IF ($PSBoundParameters.ContainsKey('Locale')) {
            $WinGetArgs += "--locale", $Locale
        }
        if ($PSBoundParameters.ContainsKey('Version')) {
            $WinGetArgs += "--Version", $Version
        }
        if ($Exact) {
            $WinGetArgs += "--Exact"
        }
        if ($PSBoundParameters.ContainsKey('Log')) {
            $WinGetArgs += "--Log", $Log
        }
        if ($PSBoundParameters.ContainsKey('Override')) {
            $WinGetArgs += "--override", $Override
        }
        if ($PSBoundParameters.ContainsKey('Location')) {
            $WinGetArgs += "--Location", $Location
        }
        if ($Force) {
            $WinGetArgs += "--Force"
        }
    }
    PROCESS {
        ## Exact, ID and Source - Talk with Demitrius tomorrow to better understand this.
        $Result = Find-WinGetPackage -Filter $Filter -Name $Name -Id $Id -Moniker $Moniker -Tag $Tag -Command $Command -Source $Source

        if ($Result.count -eq 1) {
            & "WinGet" $WingetArgs
            $Result = ""
        }
        elseif ($Result.count -lt 1) {
            Write-Error "Unable to locate package for installation"
            $Result = ""
        }
        else {
            Write-Error "Multiple packages found matching input criteria. Please refine the input."
        }
    }
    END {
        return $Result
    }
}

Function Get-WinGetPackage {
    <#
        .SYNOPSIS
        Gets installed packages on the local system. displays the packages installed on the system, as well as whether an update is available. 
        Additional options can be provided to filter the output, much like the search command.
        
        .DESCRIPTION
        By running this cmdlet with the required inputs, it will retrieve the packages installed on the local system.
        .PARAMETER Filter
        Used to search across multiple fields of the package.
        
        .PARAMETER Id
        Used to specify the Id of the package
        .PARAMETER Name
        Used to specify the Name of the package
        .PARAMETER Moniker
        Used to specify the Moniker of the package
        .PARAMETER Tag
        Used to specify the Tag of the package
        
        .PARAMETER Command
        Used to specify the Command of the package
        .PARAMETER Count
        Used to specify the maximum number of packages to return
        
        .PARAMETER Exact
        Used to specify an exact match for any parameters provided. Many of the other parameters may be used for case insensitive substring matches if Exact is not specified.
        .PARAMETER Source
        Name of the Windows Package Manager private source. Can be identified by running: "Get-WinGetSource" and using the source Name
        .PARAMETER Header
        Used to specify the value to pass as the "Windows-Package-Manager" HTTP header for a REST source.
        
        .PARAMETER AcceptSourceAgreement
        Used to accept any source agreements required by a REST source.
        .EXAMPLE
        Get-WinGetPackage -id "Publisher.Package"
        This example expects only a single configured REST source with a package containing "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Get-WinGetPackage -id "Publisher.Package" -source "Private"
        This example expects the REST source named "Private" with a package containing "Publisher.Package" as a valid identifier.
        .EXAMPLE
        Get-WinGetPackage -Name "Package"
        This example expects the REST source named "Private" with a package containing "Package" as a valid name.
    #>

    PARAM(
        [Parameter(Position = 0)] $Filter,
        [Parameter()]           $Name,
        [Parameter()]           $Id,
        [Parameter()]           $Moniker,
        [Parameter()]           $Tag,
        [Parameter()]           $Source,
        [Parameter()]           $Command,
        [Parameter()]           [ValidateRange(1, [int]::maxvalue)][int]$Count,
        [Parameter()]           [switch]$Exact,
        [Parameter()]           [ValidateLength(1, 1024)]$Header,
        [Parameter()]           [switch]$AcceptSourceAgreement
    )
    BEGIN {
        [string[]]       $WinGetArgs = @("List")
        [WinGetPackage[]]$Result = @()
        [string[]]       $IndexTitles = @("Name", "Id", "Version", "Available", "Source")

        if ($Filter) {
            ## Search across Name, ID, moniker, and tags
            $WinGetArgs += $Filter
        }
        if ($PSBoundParameters.ContainsKey('Name')) {
            ## Search for the Name
            $WinGetArgs += "--Name", $Name.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Id')) {
            ## Search for the ID
            $WinGetArgs += "--Id", $Id.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Moniker')) {
            ## Search for the Moniker
            $WinGetArgs += "--Moniker", $Moniker.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Tag')) {
            ## Search for the Tag
            $WinGetArgs += "--Tag", $Tag.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Source')) {
            ## Search for the Source
            $WinGetArgs += "--Source", $Source.Replace("…", "")
        }
        if ($PSBoundParameters.ContainsKey('Count')) {
            ## Specify the number of results to return
            $WinGetArgs += "--Count", $Count
        }
        if ($Exact) {
            ## Search using exact values specified (case sensitive)
            $WinGetArgs += "--Exact"
        }
        if ($PSBoundParameters.ContainsKey('Header')) {
            ## Pass the value specified as the Windows-Package-Manager HTTP header
            $WinGetArgs += "--header", $Header
        }
        if ($AcceptSourceAgreement) {
            ## Accept source agreements
            $WinGetArgs += "--accept-source-agreements"
        }
    }
    PROCESS {
        $List = Invoke-WinGetCommand -WinGetArgs $WinGetArgs -IndexTitles $IndexTitles
    
        foreach ($Obj in $List) {
            $Result += [WinGetPackage]::New($Obj) 
        }
    }
    END {
        return $Result
    }
}   


function new-aadgroups {
    [cmdletbinding()]
        
    param
    (
        $appid,
        $appname,
        $grouptype
    )
    switch ($grouptype) {
        "install" {
            $groupname = $appname + " Install Group"
            $nickname = $appid + "install"
            $groupdescription = "Group for installation and updating of $appname application"
        }
        "uninstall" {
            $groupname = $appname + " Uninstall Group"
            $nickname = $appid + "uninstall"
            $groupdescription = "Group for uninstallation of $appname application"
        }
    }

    $grp = New-MgGroup -DisplayName $groupname -Description $groupdescription -MailEnabled:$False -MailNickName $nickname -SecurityEnabled:$True

    return $grp.id

}

function new-detectionscript {
    param
    (
        $appid,
        $appname
    )
    $detect = @'
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
    if ($ResolveWingetPath){
           $WingetPath = $ResolveWingetPath[-1].Path
    }
$Winget = $WingetPath + "\winget.exe"
$upgrades = &$winget upgrade
if ($upgrades -match SETAPPID) {
    Write-Host "Upgrade available for: SETAPPNAME"
    exit 1
}
else {
        Write-Host "No Upgrade available"
        exit 0
}
'@
    $detect2 = $detect -replace "SETAPPID", $appid
    $detect3 = $detect2 -replace "SETAPPNAME", $appname

    return $detect3
}

function new-remediationscript {
    param
    (
        $appid,
        $appname
    )
    $remediate = @'
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
    if ($ResolveWingetPath){
        $WingetPath = $ResolveWingetPath[-1].Path
    }
        
    $Winget = $WingetPath + "\winget.exe"
    &$winget upgrade --id SETAPPID --silent --force --accept-package-agreements --accept-source-agreements
'@
    $remediate2 = $remediate -replace "SETAPPID", $appid
    return $remediate2

}

function new-proac {
    param
    (
        $appid,
        $appname,
        $groupid
    )
    $detectscriptcontent = new-detectionscript -appid $appid -appname $appname
    $detect = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($detectscriptcontent))
    $remediatecriptcontent = new-remediationscript -appid $appid -appname $appname
    $remediate = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remediatecriptcontent))

    $DisplayName = $appname + " Upgrade"
    $Description = "Upgrade $appname application"
    ##RunAs can be "system" or "user"
    $RunAs = "system"
    ##True for 32-bit, false for 64-bit
    $RunAs32 = $false
    ##Daily or Hourly
    #$ScheduleType = "Hourly"
    ##How Often
    $ScheduleFrequency = "1"
    ##Start Time (if daily)
    #$StartTime = "01:00"
    
    $proacparams = @{
        publisher                = "Microsoft"
        displayName              = $DisplayName
        description              = $Description
        detectionScriptContent   = $detect
        remediationScriptContent = $remediate
        runAs32Bit               = $RunAs32
        enforceSignatureCheck    = $false
        runAsAccount             = $RunAs
        roleScopeTagIds          = @(
            "0"
        )
        isGlobalScript           = "false"
    }
    $paramsjson = $proacparams | convertto-json
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceHealthScripts"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"

    $proactive = Invoke-MgGraphRequest -Uri $uri -Method POST -Body $paramsjson -ContentType "application/json"


    $assignparams = @{
        DeviceHealthScriptAssignments = @(
            @{
                target               = @{
                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    groupId       = $groupid
                }
                runRemediationScript = $true
                runSchedule          = @{
                    "@odata.type" = "#microsoft.graph.deviceHealthScriptHourlySchedule"
                    interval      = $scheduleFrequency
                }
            }
        )
    }
    $assignparamsjson = $assignparams | convertto-json -Depth 10
    $remediationID = $proactive.ID
        
        
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceHealthScripts"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$remediationID/assign"
        
    Invoke-MgGraphRequest -Uri $uri -Method POST -Body $assignparamsjson -ContentType "application/json"

    return "Success"

}

function new-intunewinfile {
    param
    (
        $appid,
        $appname,
        $apppath,
        $setupfilename
    )
    . $intuneapputiloutput -c "$apppath" -s "$setupfilename" -o "$apppath" -q

}

function new-detectionscript {
    param
    (
        $appid,
        $appname
    )
    $detection = @"
    `$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
        if (`$ResolveWingetPath){
               `$WingetPath = `$ResolveWingetPath[-1].Path
        }
    
    `$Winget = `$WingetPath + "\winget.exe"
    `$wingettest = &`$winget list --id $appid
    if (`$wingettest -like "*$appid*"){
        Write-Host "Found it!"
    }
"@
    return $detection

}


function new-installscript {
    param
    (
        $appid,
        $appname
    )
    $install = @"
    `$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
        if (`$ResolveWingetPath){
               `$WingetPath = `$ResolveWingetPath[-1].Path
        }
    
    `$Winget = `$WingetPath + "\winget.exe"
    &`$winget install --id $appid --silent --force --accept-package-agreements --accept-source-agreements
"@
    return $install

}

function new-uninstallscript {
    param
    (
        $appid,
        $appname
    )
    $uninstall = @"
    `$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
        if (`$ResolveWingetPath){
               `$WingetPath = `$ResolveWingetPath[-1].Path
        }
    
    `$Winget = `$WingetPath + "\winget.exe"
    &`$winget uninstall --id $appid --silent --force --accept-package-agreements --accept-source-agreements
"@
    return $uninstall

}

function grant-win32app {
    param
    (
        $appname,
        $installgroup,
        $uninstallgroup
    )
    $Application = Get-IntuneApplication | where-object { $_.displayName -eq "$appname" }

    #Install
    $ApplicationId = $Application.id
    $TargetGroupId1 = $installgroup
    $InstallIntent1 = "required"
    
    
    #Uninstall
    $ApplicationId = $Application.id
    $TargetGroupId = $uninstallgroup
    $InstallIntent = "uninstall"
    $JSON = @"
    
    {
        "mobileAppAssignments": [
          {
            "@odata.type": "#microsoft.graph.mobileAppAssignment",
            "target": {
            "@odata.type": "#microsoft.graph.groupAssignmentTarget",
            "groupId": "$TargetGroupId1"
            },
            "intent": "$InstallIntent1"
        },
        {
            "@odata.type": "#microsoft.graph.mobileAppAssignment",
            "target": {
            "@odata.type": "#microsoft.graph.groupAssignmentTarget",
            "groupId": "$TargetGroupId"
            },
            "intent": "$InstallIntent"
        }
        ]
    }
    
"@
    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$ApplicationId/assign" -Method POST -Body $JSON
    
}

function new-win32app {
    [cmdletbinding()]
        
    param
    (
        $appid,
        $appname,
        $appfile,
        $installcmd,
        $uninstallcmd,
        $detectionfile
    )
    # Defining Intunewin32 detectionRules
    $PSRule = New-DetectionRule -PowerShell -ScriptFile $detectionfile -enforceSignatureCheck $false -runAs32Bit $false


    # Creating Array for detection Rule
    $DetectionRule = @($PSRule)

    $ReturnCodes = Get-DefaultReturnCodes

    # Win32 Application Upload
    $appupload = Invoke-UploadWin32Lob -SourceFile "$appfile" -DisplayName "$appname" -publisher "Winget" `
        -description "$appname Winget Package" -detectionRules $DetectionRule -returnCodes $ReturnCodes `
        -installCmdLine "$installcmd" `
        -uninstallCmdLine "$uninstallcmd"

    return $appupload

}

############################################################################################################
######                          END FUNCTIONS SECTION                                               ########
############################################################################################################

write-host "Grabbing Tenant ID"
#Get Tenant ID
$uri = "https://graph.microsoft.com/beta/organization"
$tenantdetails = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
$tenantid = $tenantdetails.id
write-host "Tenant ID is $tenantid"


###############################################################################################################
######                                          Get YAML                                                 ######
###############################################################################################################

##Grab GitHub Commits
write-host "Finding Latest YAML Commit from Repo $reponame in $ownername GitHub"
$uri = "https://api.github.com/repos/$ownername/$reponame/commits"

$headers = @{
    'Authorization' = 'Bearer '+$token
    'Accept' = 'application/vnd.github+json'
}


$events = (Invoke-RestMethod -Uri $uri -Method Get -Headers $headers).commit

##Loop through until we hit a YAML file
##We don't want to grab anything else in the repo
##When we find a YAML, break the loop
foreach ($event in $events) {
$eventsuri = $event.url
$commitid = Split-Path $eventsuri -Leaf
$commituri = "https://api.github.com/repos/$ownername/$reponame/commits/$commitid"
$commitfilename2 = ((Invoke-RestMethod -Uri $commituri -Method Get -Headers $headers).Files).raw_url
$commitfileext = split-path $commitfilename2 -Leaf
$commitext = [System.IO.Path]::GetExtension($commitfileext)
write-host $commitext
if ($commitext -eq ".yaml") {
$commitfilename = $commitfilename2
break;
}
}
write-host "$commitfilename Found"

$filename = $commitfilename.Substring($commitfilename.LastIndexOf("/") + 1)

##File Name
$templateFilePath = $path + $filename
write-host "Output to $templatefilepath"
###############################################################################################################
######                                          Download YAML                                            ######
###############################################################################################################
write-host "Downloading YAML"
Invoke-WebRequest -Uri $commitfilename -OutFile $templateFilePath -UseBasicParsing -Headers @{'Cache-Control'='no-cache'}
write-host "Investigating YAML"
[string[]]$fileContent = Get-Content $templateFilePath
$content = ''
foreach ($line in $fileContent) { $content = $content + "`n" + $line }
$obj = ConvertFrom-Yaml $content
$tags = $obj.Tags
foreach ($tag in $tags) {
    if ($tag -like '*ICON*') {
        $icon = $tag
    }
    if ($tag -like '*DETECTION*') {
        $detection = $tag
    }
    if ($tag -like 'UNINSTALLCOMMAND*') {
        $uninstall = $tag
    }
    if ($tag -like '*ADGROUPI*') {
        $adgroupi = $tag
    }
    if ($tag -like '*ADGROUPU*') {
        $adgroupu = $tag
    }
}

$icon2 = $icon -split '='
$iconpath = $icon2[1]
$iconname = $iconpath.Substring($iconpath.LastIndexOf("/") + 1)
$icondownload = $path + $iconname


##Download Icon
write-host "Downloading Icon"
Invoke-WebRequest `
   -Uri $iconpath `
   -OutFile $icondownload `
   -UseBasicParsing `
   -Headers @{"Cache-Control"="no-cache"}

$detection2 = $detection -split '='
$detectionrule = $detection2[1]

$uninstall2 = $uninstall -split '='
$uninstallcommand = $uninstall2[1]

$adgroupi2 = $adgroupi -split '='
$adgroupinstall = $adgroupi2[1]

$adgroupu2 = $adgroupu -split '='
$adgroupuninstall = $adgroupu2[1]

$publisher = $obj.publisher
$name = $obj.packagename
$description = $obj.shortdescription
$appversion = $obj.PackageVersion
$infourl = $obj.PackageUrl


$groupname1 = $name + "-INSTALL"
#Create Install Group
write-host "Creating Install Group"
$installgroup = New-MgGroup -DisplayName $adgroupinstall -Description "Install group for $name" -SecurityEnabled -MailEnabled:$false -MailNickName "group" 
write-host "Install Group Created"

$groupname2 = $name + "-UNINSTALL"
#Create Uninstall Group
write-host "Creating Uninstall Group"
$uninstallgroup = New-MgGroup -DisplayName $adgroupuninstall -Description "Uninstall group for $name" -SecurityEnabled -MailEnabled:$false -MailNickName "group" 
write-host "Uninstall Group Created"

$setupfile = "$path$name-Install.ps1"
$setupfilename = "$name-Install.ps1"
##Create Install File
write-host "Creating Install File"
Set-Content $setupfile @'

$filename2 = 
'@ -NoNewline
add-Content $setupfile @"
"$filename"
"@
add-Content $setupfile @'
$filename = $filename2.Substring($filename2.LastIndexOf("/") + 1)
   $curDir = Get-Location
   $filebase = Join-Path $curDir $filename
   $Winget = Get-ChildItem -Path (Join-Path -Path (Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps") -ChildPath "Microsoft.DesktopAppInstaller*_x64*\Winget.exe")
   Start-Process -NoNewWindow -FilePath $winget -ArgumentList "settings --enable LocalManifestFiles"
   Start-Process -NoNewWindow -FilePath $winget -ArgumentList "install --silent  --manifest $filename"

'@
write-host "Install File Created"
$path4 = $detectionrule
$fname = $path4.Substring($path4.LastIndexOf("\") + 1)
$fpath = Split-Path -Path $path4

    # Package as .intunewin file
    write-host "Creating .intunewin File"
    $SourceFolder = $path
    $OutputFolder = $path
    $appid = New-Guid
    $intunewinpath = $apppath + "\install$name.intunewin"
    new-intunewinfile -appid $appid -appname $name -apppath $OutputFolder -setupfilename $setupfilename
    Write-Host "Intunewin $intunewinpath Created"
    $sleep = 10
    foreach ($i in 0..$sleep) {
        Write-Progress -Activity "Sleeping for $($sleep-$i) seconds" -PercentComplete ($i / $sleep * 100) -SecondsRemaining ($sleep - $i)
        Start-Sleep -s 1
    }
    write-host ".intunewin File Created"

    $IntuneWinFile = Get-ChildItem -Path  $path | Where-Object Name -Like "*.intunewin"
    $IntuneWinFile.Name
    $intunewincreated = $path + "\" + $intunewinfile.Name
    # Create custom display name like 'Name' and 'Version'
    write-host "Creating Custom Display Name"
    $DisplayName = $name

    # Create detection rule
    write-host "Creating Detection Rule"
    # Defining Intunewin32 detectionRules
$FileRule = New-DetectionRule -File -Path "$fpath" `
-FileOrFolderName "$fname" -FileDetectionType exists -check32BitOn64System False

# Creating Array for detection Rule
$DetectionRule = @($FileRule)

$ReturnCodes = Get-DefaultReturnCodes

    # Add new EXE Win32 app
    write-host "Adding EXE Win32 App"
    $InstallationScriptFile = Get-ChildItem -Path $path | Where-Object Name -Like "*-Install.ps1"
    $InstallCommandLine = "powershell.exe -ExecutionPolicy Bypass -File .\$($InstallationScriptFile.Name)"
    $UninstallCommandLine = $uninstallcommand
    $ImageFile = $icondownload
    #$Icon = New-IntuneWin32AppIcon -FilePath $ImageFile
    Invoke-UploadWin32Lob -SourceFile "$intunewincreated" -DisplayName "$DisplayName" -publisher "$publisher" `
-description "$description" -detectionRules $DetectionRule -returnCodes $ReturnCodes `
-installCmdLine "$installcommandline" `
-uninstallCmdLine "$uninstallcommandline"


    ##Assignments
    write-host "Creating Assignments"
    $win32app = Get-IntuneApplication | Where-Object { $_.displayName -eq "$DisplayName" }

    #Install
$installid = $installgroup.Id
$uninstallid = $uninstallgroup.Id
write-host "Assigning $DisplayName version $appversion"
grant-win32app -appname $DisplayName -installgroup $installid -uninstallgroup $uninstallid
Write-Host "Assigned $installgroup as Required Install to $appname"
Write-Host "Assigned $uninstallgroup as Required Uninstall to $appname"

    
