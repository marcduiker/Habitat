<#
    This script only contains a Log function and can be imported and called by other ps1 scripts.
#>
function Log
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, ValueFromPipeline=$True, Mandatory=$True)]
        $Message,
        [Parameter(Position=1, Mandatory=$False)]
        $FontColor = "Cyan"
    )
    
    $timeStamp = Get-Date -UFormat '%Y%m%d-%H:%M:%S'
    $messageWithTimeStamp = $timeStamp + ' ' + $Message

    Write-Host $messageWithTimeStamp -ForegroundColor $FontColor
    if($Global:LogToFile)
    {
        Write-Output $messageWithTimeStamp | Out-File -FilePath $Global:LogToFile -Append
    }
}