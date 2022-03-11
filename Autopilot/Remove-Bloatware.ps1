<#
Script to remove HP and Microsoft bloatware
Original: https://gist.github.com/mark05e/a79221b4245962a477a49eb281d97388
Modified by Joachim Berghmans

To run the script manually or using Intune you will need to copy the file uninstallHPCO.iss to C:\windows\install manually.
This script is meant to be wrapped as an intunewin file and deployed during Autopilot or as a Win32 app
Do not not forget to include uninstallHPCO.iss when creating your Win32 app by saving the file in the same folder as your script

#>


function Write-LogEntry {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
            [ValidateNotNullOrEmpty()]
            [string]$Value,
    
            [parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("1", "2", "3")]
            [string]$Severity,
    
            [parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
            [ValidateNotNullOrEmpty()]
            [string]$FileName = "Remove-HP-Bloatware.log"
        )
        # Determine log file location
        $LogFilePath = Join-Path -Path (Join-Path -Path $env:windir -ChildPath "Install") -ChildPath $FileName
        
        # Construct time stamp for log entry
        $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
        
        # Construct date for log entry
        $Date = (Get-Date -Format "MM-dd-yyyy")
        
        # Construct context for log entry
        $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
        
        # Construct final log entry
        $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""RemoveHPBloatware"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
        
        # Add value to log file
        try {
            Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
        }
        catch [System.Exception] {
            Write-LogEntry -Message "Unable to append log entry to Remove-HP-Bloatware.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
        }
    }



#Remove HP Documentation
if (Test-Path "C:\Program Files\HP\Documentation\Doc_uninstall.cmd" -PathType Leaf){
Try {
    Invoke-Item "C:\Program Files\HP\Documentation\Doc_uninstall.cmd"
    Write-LogEntry -Value "Successfully removed provisioned package: HP Documentation" -Severity 1
    }
Catch [System.Exception] {
        Write-LogEntry -Message "HP Documentation not installed $($_.Exception.Message)" -Severity 2
        }
}

#Remove HP Support Assistant silently

$HPSAuninstall = "C:\Program Files (x86)\HP\HP Support Framework\UninstallHPSA.exe"

if (Test-Path -Path "HKLM:\Software\WOW6432Node\Hewlett-Packard\HPActiveSupport") {
Try {
        Remove-Item -Path "HKLM:\Software\WOW6432Node\Hewlett-Packard\HPActiveSupport"
        Write-LogEntry -Message "HP Support Assistant regkey deleted $($_.Exception.Message)" -Severity 1
    }
Catch [System.Exception] {
        Write-LogEntry -Message "HP Support Assistant regkey not found $($_.Exception.Message)" -Severity 2
        }
}

if (Test-Path $HPSAuninstall -PathType Leaf) {
    Try {
        & $HPSAuninstall /s /v/qn UninstallKeepPreferences=FALSE
        Write-LogEntry -Value "Successfully removed provisioned package: HP Support Assistant silently" -Severity 1
    }
        Catch [System.Exception] {
        Write-LogEntry -Message "HP Support Assistant Uninstaller not found $($_.Exception.Message)" -Severity 2
        }
}


#Remove HP Connection Optimizer

$HPCOuninstall = "C:\Program Files (x86)\InstallShield Installation Information\{6468C4A5-E47E-405F-B675-A70A70983EA6}\setup.exe"

#copy uninstall file
xcopy /y .\uninstallHPCO.iss C:\Windows\install\

if (Test-Path $HPCOuninstall -PathType Leaf){
Try {
        & $HPCOuninstall -runfromtemp -l0x0413  -removeonly -s -f1C:\Windows\install\uninstallHPCO.iss
        Write-LogEntry -Value "Successfully removed HP Connection Optimizer" -Severity 1
        }
Catch [System.Exception] {
        Write-LogEntry -Message "HP Connection Optimizer $($_.Exception.Message)" -Severity 2
        }
}


#List of packages to install
$UninstallPackages = @(
    "AD2F1837.HPJumpStarts"
    "AD2F1837.HPPCHardwareDiagnosticsWindows"
    "AD2F1837.HPPowerManager"
    "AD2F1837.HPPrivacySettings"
    "AD2F1837.HPSupportAssistant"
    "AD2F1837.HPSureShieldAI"
    "AD2F1837.HPSystemInformation"
    "AD2F1837.HPQuickDrop"
    "AD2F1837.HPWorkWell"
    "AD2F1837.myHP"
    "AD2F1837.HPDesktopSupportUtilities"
    "AD2F1837.HPEasyClean"
    "AD2F1837.HPSystemInformation"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.People"
    "Microsoft.StorePurchaseApp"
    "microsoft.windowscommunicationsapps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.XboxApp"
    "Microsoft.Wallet"
    "Microsoft.SkyeApp"
    "Microsoft.BingWeather"
    "Tile.TileWindowsApplication"
)

# List of programs to uninstall
$UninstallPrograms = @(
    "HP Connection Optimizer"
    "HP Documentation"
    "HP MAC Address Manager"
    "HP Notifications"
    "HP Security Update Service"
    "HP System Default Settings"
    "HP Sure Click"
    "HP Sure Run"
    "HP Sure Recover"
    "HP Sure Sense"
    "HP Sure Sense Installer"
    "HP Wolf Security Application Support for Sure Sense"
    "HP Wolf Security Application Support for Windows"
    "HP Client Security Manager"
    "HP Wolf Security"
)

#Get a list of installed packages matching our list
$InstalledPackages = Get-AppxPackage -AllUsers | Where-Object {($UninstallPackages -contains $_.Name)}

#Get a list of Provisioned packages matching our list
$ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object  {($UninstallPackages -contains $_.DisplayName)}

#Get a list of installed programs matching our list
$InstalledPrograms = Get-Package | Where-Object  {$UninstallPrograms -contains $_.Name}


# Remove provisioned packages first
ForEach ($ProvPackage in $ProvisionedPackages) {

    Write-LogEntry -Value "Attempting to remove provisioned package: [$($ProvPackage.DisplayName)]" -Severity 1

    Try {
        $Null = Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
        Write-LogEntry -Value "Successfully removed provisioned package: [$($ProvPackage.DisplayName)]" -Severity 1
    }
    Catch [System.Exception] {
        Write-LogEntry -Message "Failed to remove provisioned package: [$($ProvPackage.DisplayName)] Error message: $($_.Exception.Message)" -Severity 3
    }
}

# Remove appx packages
ForEach ($AppxPackage in $InstalledPackages) {
                                            
    Write-LogEntry -Value "Attempting to remove Appx package: [$($AppxPackage.Name)] " -Severity 1

    Try {
        $Null = Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
        Write-LogEntry -Value "Successfully removed Appx package: [$($AppxPackage.Name)]" -Severity 1
    }
    Catch [System.Exception] {
        Write-LogEntry -Message "Failed to remove Appx package: [$($AppxPackage.Name)] Error message: $($_.Exception.Message)" -Severity 3
    }
}

# Remove installed programs
$InstalledPrograms | ForEach-Object {

    Write-LogEntry -Value "Attempting to uninstall: [$($_.Name)]"  -Severity 1

    Try {
        $Null = $_ | Uninstall-Package -AllVersions -Force -ErrorAction Stop
        Write-LogEntry -Value "Successfully uninstalled: [$($_.Name)]" -Severity 1
    }
    Catch [System.Exception] {
        Write-LogEntry -Message "Failed to uninstall: [$($_.Name)] Error message: $($_.Exception.Message)" -Severity 3
    }
}

#Fallback attempt 1 to remove HP Wolf Security using msiexec
Try {
    MsiExec /x "{0E2E04B0-9EDD-11EB-B38C-10604B96B11E}" /qn /norestart
    Write-LogEntry -Value "Fallback to MSI uninistall for HP Wolf Security initiated" -Severity 1
}
Catch [System.Exception] {
    Write-LogEntry -Message "Failed to uninstall HP Wolf Security using MSI - Error message: $($_.Exception.Message)" -Severity 3
}

#Fallback attempt 2 to remove HP Wolf Security using msiexec
Try {
    MsiExec /x "{4DA839F0-72CF-11EC-B247-3863BB3CB5A8}" /qn /norestart
    Write-LogEntry -Value "Fallback to MSI uninistall for HP Wolf 2 Security initiated" -Severity 1
}
Catch [System.Exception] {
    Write-LogEntry -Message "Failed to uninstall HP Wolf Security 2 using MSI - Error message: $($_.Exception.Message)" -Severity 3
}


#Remove shortcuts
$pathTCO = "C:\ProgramData\HP\TCO"
$pathTCOc = "C:\Users\Public\Desktop\TCO Certified.lnk"
$pathOS = "C:\Program Files (x86)\Online Services"
$pathFT = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Free Trials.lnk"

if (Test-Path $pathTCO) {
    Try {
        Remove-Item -LiteralPath $pathTCO -Force -Recurse
        Write-LogEntry -Value "Shortcut for $pathTCO removed" -Severity 1
    }
        Catch [System.Exception] {
        Write-LogEntry -Message "Folder $pathTCO not found $($_.Exception.Message)" -Severity 2
        }
    }

if (Test-Path $pathTCOc -PathType Leaf) {
    Try {
        Remove-Item -Path $patchTCOc  -Force -Recurse
        Write-LogEntry -Value "Shortcut for $pathTCOc removed" -Severity 1
    }
        Catch [System.Exception] {
        Write-LogEntry -Message "Folder $pathTCOc not found $($_.Exception.Message)" -Severity 2
        }
    }

if (Test-Path $pathOS) {
    Try {
        Remove-Item -LiteralPath $pathOS  -Force -Recurse
        Write-LogEntry -Value "Shortcut for $pathOS removed" -Severity 1
    }
        Catch [System.Exception] {
        Write-LogEntry -Message "Folder $pathOS not found $($_.Exception.Message)" -Severity 2
        }
    }

    if (Test-Path $pathFT -PathType Leaf) {
    Try {
        Remove-Item -Path $pathFT -Force -Recurse
        Write-LogEntry -Value "Shortcut for $pathFT removed" -Severity 1
    }
        Catch [System.Exception] {
        Write-LogEntry -Message "Folder $pathFT not found $($_.Exception.Message)" -Severity 2
        }
    }

#Clean up uninstall file for HP Connection Optimizer
Remove-Item -Path C:\Windows\install\uninstallHPCO.iss -Force
