<#
# Start Logging
#>
$LogPrefix = "Log-WinTLS1011DeprecatedDisable-$Env:Computername-"
$LogDate = Get-Date -Format dd-MM-yyyy-HH-mm
$LogName = $LogPrefix + $LogDate + ".txt"
Start-Transcript -Path "C:\Temp\$LogName"

$date = Get-Date -Format "MM-dd-yyyy_HH-mm-ss"
#write-host $date  

# Read the list of servers from a file
$servers = Get-Content -Path "C:\temp\ServerList.txt"

# Create an empty array to store the results
$results = @()


foreach ($server in $servers) 
{
    # Check if the server is responding to ping or Test-NetConnection
    $ping = Test-Connection -ComputerName $server -Count 1 -Quiet
    $port445 = Test-NetConnection -ComputerName $server -Port 445 -InformationLevel Quiet
    $port5985 = Test-NetConnection -ComputerName $server -Port 5985 -InformationLevel Quiet

    if ($ping -or $port445 -or $port5985) 
    {
        $status = "Server Responding"

#When you use Invoke command, the commands passed under scriptblock are executed local to that server. 
#So ensure the commands which you specify under script block are the ones which can be executed locally successfully
    Invoke-Command -Computername $server -ScriptBlock {
        function Test-RegistryValue {

    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Name
    )

    try {
        $ItemProperty = Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Name -ErrorAction Stop
        if ($ItemProperty -eq "1") {
            return $true
        }
        else {
            return $false
        }
    }

    catch {
        return $false
    }
}

<#
# Using the below function we can create a new value (when $False) or update an existing value to 1 (when $True)
# Set-ItemProperty doesn't support -PropertyType parameter therefore can't handle both scenarios
#>
function Update-RegistryValue {

    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Name,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]$Exists
    )

    try {
        if ($Exists -eq $False) {
            New-ItemProperty -Path $Path -Name $Name -Value "0" -PropertyType "DWord" -ErrorAction Stop
            Write-Host "$Path\$Name has been created"
        }
        else {
            Set-ItemProperty -Path $Path -Name $Name -Value "0" -ErrorAction Stop
            Write-Host "$Path\$Name has been updated"
        }
        return $true
    }

    catch {
        return $false
    }
}

        try {

             <# 
             # Create keys if they do not exist
             # New-Item can only create a key if the higher level key exists
             #>
             
             $Paths = @(
             "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0", 
             "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client", 
             "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server", 
             "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1", 
             "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client", 
             "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server")

        foreach ($Path in $Paths) 
       {
         $PathExists = Test-Path -Path $Path
         if ($PathExists -eq $False) 
         {
         New-Item -Path $Path
         }
        }

<#
# Disable TLS 1.0 Client
#>

$TLS10ClientKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"
$TLS10ClientName = "Enabled"
$TLS10ClientExists = Test-RegistryValue -Path $TLS10ClientKey -Name $TLS10ClientName
Update-RegistryValue -Exists $TLS10ClientExists -Path $TLS10ClientKey -Name $TLS10ClientName

<#
# Disable TLS 1.0 Server
#>

$TLS10ServerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
$TLS10ServerName = "Enabled"
$TLS10ServerExists = Test-RegistryValue -Path $TLS10ServerKey -Name $TLS10ServerName
Update-RegistryValue -Exists $TLS10ServerExists -Path $TLS10ServerKey -Name $TLS10ServerName

<#
# Disable TLS 1.1 Client
#>

$TLS11ClientKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
$TLS11ClientName = "Enabled"
$TLS11ClientExists = Test-RegistryValue -Path $TLS11ClientKey -Name $TLS11ClientName
Update-RegistryValue -Exists $TLS11ClientExists -Path $TLS11ClientKey -Name $TLS11ClientName

<#
# Disable TLS 1.1 Server
#>

$TLS11ServerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
$TLS11ServerName = "Enabled"
$TLS11ServerExists = Test-RegistryValue -Path $TLS11ServerKey -Name $TLS11ServerName
Update-RegistryValue -Exists $TLS11ServerExists -Path $TLS11ServerKey -Name $TLS11ServerName
#>
$TLS10Client = "TLS 1.0 Client Successfully Closed"
$TLS10Server = "TLS 1.0 Server Successfully Closed"
$TLS11Client = "TLS 1.1 Client Successfully Closed"
$TLS11Server = "TLS 1.0 Server Successfully Closed"

#Use below command to perform Restart if you do not want to manually restart the server
#Restart-Computer -Computername $env:computername -Force

        }
        catch 
        {
            Write-Host "An error occurred while creating registry keys on server $server"
        }
       
    }  
    
}

    else 
    {
        # If the server is not responding, set status to "Not Responding"
        $status = "Server Not Responding/Communicating"
        $TLS10Client = "NA"
        $TLS10Server = "NA"
        $TLS11Client = "NA"
        $TLS11Server = "NA"
    }

    # Add the result to the array
    $results += [PSCustomObject]@{
        ServerName = $server
        Status = $status
        TLS10_Client = $TLS10Client
        TLS10_Server = $TLS10Server
        TLS11_Client = $TLS11Client
        TLS11_Server = $TLS11Server
        
        
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path "C:\temp\TLS_Status_$date.csv" -NoTypeInformation

Write-Output "TLS status has been exported to C:\temp\ location"

<#
# Stop Logging
#>
Stop-Transcript