﻿#Test if its run by Admin and run it elevated

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

##########################################################################################
#   Functions
##########################################################################################

function WriteInfo($message)
{
    Write-Host $message
}

function WriteInfoHighlighted($message)
{
    Write-Host $message -ForegroundColor Cyan
}

function WriteSuccess($message)
{
    Write-Host $message -ForegroundColor Green
}

function WriteError($message)
{
    Write-Host $message -ForegroundColor Red
}

function WriteErrorAndExit($message)
{
	Write-Host $message -ForegroundColor Red
	Write-Host "Press any key to continue ..."
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
	$HOST.UI.RawUI.Flushinputbuffer()
	Exit
}

Function Get-ScriptDirectory
    {
    Split-Path $script:MyInvocation.MyCommand.Path
    }


##########################################################################################
#   Cleanup
##########################################################################################
$Workdir=get-scriptdirectory

#load LabConfig
. "$($workdir)\LabConfig.ps1"
$prefix=$LabConfig.Prefix

if (!$prefix){
    WriteErrorAndExit "Prefix is empty. Exiting"
}

WriteInfoHighlighted "VMs:"
Write-Output (get-vm -Name $prefix*).name
WriteInfoHighlighted "SwitchName:"
Write-Output (Get-VMSwitch $prefix*).name
WriteInfo ""

$answer=read-host "This script will remove all VMs and switches starting with $prefix (all above) Are you sure? (type  Y )"

if ($answer -eq "Y"){
    Stop-VM $prefix'DC' -TurnOff -Force
    Restore-VMsnapshot -VmName $prefix'DC' -Name Initial -Confirm:$False
    Start-Sleep 2
    Remove-VMsnapshot -VMName $prefix'DC' -name Initial -Confirm:$False
    get-VM $prefix* | Stop-VM -TurnOff -Force
    get-VM $prefix* | Remove-VM -Force
    Remove-VMSwitch $prefix* -Force

    # This is only needed if you kill deployment script in middle when it mounts VHD into mountdir. If mountdir is empty, it will throw warning..
    &"$workdir\Tools\dism\dism" /Unmount-Image /MountDir:$Workdir\temp\mountdir /discard

    remove-item $workdir\LAB\VMs -Confirm:$False -Recurse
    remove-item $workdir\temp -Confirm:$False -Recurse -ErrorAction SilentlyContinue 

    #Unzipping configuration files as VM was removed few lines ago-and it deletes vm configuration... 
    $zipfile= "$workdir\LAB\DC\Virtual Machines.zip"
    $zipoutput="$workdir\LAB\DC\"

    Expand-Archive -Path $zipfile -DestinationPath $zipoutput

    WriteSuccess "Press any key to close window ..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
}
else {
    WriteErrorAndExit "You did not type Y"
}