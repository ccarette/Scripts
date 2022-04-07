$logfile = "C:\Windows\Logs\UpdatesReady.csv"
if (Test-Path -Path $logfile)
    { 
        Remove-Item $logfile
    }
# EnableStart WindowsUpdateService
Set-Service -Name 'wuauserv' -StartupType 'Manual' ; Start-Service -Name 'wuauserv'

# Default Service = 'Windows Server Update Service' - CFR Local GPO
$WindowsUpdateSearch = New-Object -ComObject 'Microsoft.Update.Searcher'

# Search Windows Updates
Try	{ $WindowsUpdateList = $WindowsUpdateSearch.Search($Null).Updates }
	Catch 
		{
        	Write-Output 'WSUS not Reachable. No Internet Connection. Please Check DNS & Gateway Config.'
        	Start-Sleep -Seconds 5
		Exit
		}
If	( $WindowsUpdateList.Count -eq 0 )
		{
		Write-Output "$(get-date) No Updates Available." | Out-File $logfile -Append
		Start-Sleep -Seconds 5
    		Exit
		}
	Else {}

$HotFixList = Get-HotFix | Select-Object -Property HotFixID,InstalledOn | Sort-Object -Property InstalledOn

$HotFixID = $HotFixList.HotFixID 
$KBvalue = $WindowsUpdateList | Select-Object -Property Title 
foreach ($a in $KBvalue.Title) 
    {
        $KB = $a.Substring( $a.IndexOf('KB') , 9 ) | Add-Content C:\Windows\Logs\UpdatesReady.csv
    }
$content = Get-Content -Path $logfile
foreach ($value in $content)
    {
        if ($value -notin $HotFixID) 
            {
            Write-host "$(get-date) Missing update $value" | Out-File $logfile -Append
        
            }
        Else{}
    }
