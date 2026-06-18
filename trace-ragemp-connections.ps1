$ErrorActionPreference = 'SilentlyContinue'

$durationSeconds = if ($args.Count -gt 0) { [int]$args[0] } else { 45 }
$sampleMs = if ($args.Count -gt 1) { [int]$args[1] } else { 25 }
$launchUpdater = $args -contains '-LaunchUpdater'
$deadline = (Get-Date).AddSeconds($durationSeconds)
$seen = New-Object 'System.Collections.Generic.HashSet[string]'

Write-Host "Tracing RAGE:MP-related TCP connections and DNS for $durationSeconds seconds, sampling every $sampleMs ms..."
Write-Host "Start: $(Get-Date -Format o)"
Write-Host ""

if ($launchUpdater) {
    Write-Host "Launching C:\RAGEMP\updater.exe..."
    Start-Process -FilePath 'C:\RAGEMP\updater.exe' -WorkingDirectory 'C:\RAGEMP' | Out-Null
}

while ((Get-Date) -lt $deadline) {
    $procs = Get-CimInstance Win32_Process |
        Where-Object {
            $_.ExecutablePath -like 'C:\RAGEMP\*' -or
            $_.CommandLine -like '*RAGEMP*' -or
            $_.Name -in @('updater.exe', 'ragemp_v.exe', 'ragemp_ui.exe', 'EACLauncher.exe')
        }

    $ids = @($procs.ProcessId | ForEach-Object { [int]$_ })

    $rgsvcDns = @(Get-DnsClientCache |
        Where-Object { $_.Entry -match 'rgsvc' -and $_.Type -eq 1 } |
        ForEach-Object { $_.Data })

    Get-NetTCPConnection |
        Where-Object {
            $_.RemoteAddress -and
            $_.RemoteAddress -notin @('0.0.0.0', '::') -and
            (
                ($ids.Count -gt 0 -and $ids -contains [int]$_.OwningProcess) -or
                ($_.RemotePort -eq 443 -and $_.RemoteAddress -in @('127.0.0.1', '::1')) -or
                ($rgsvcDns -contains $_.RemoteAddress)
            )
        } |
            ForEach-Object {
                $proc = $procs | Where-Object ProcessId -eq $_.OwningProcess | Select-Object -First 1
                if (-not $proc) {
                    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($_.OwningProcess)"
                }
                $key = "$($_.OwningProcess)|$($_.LocalAddress):$($_.LocalPort)|$($_.RemoteAddress):$($_.RemotePort)|$($_.State)"

                if ($seen.Add($key)) {
                    $rdns = ''
                    try { $rdns = ([System.Net.Dns]::GetHostEntry($_.RemoteAddress)).HostName } catch {}

                    [pscustomobject]@{
                        Time        = Get-Date -Format 'HH:mm:ss.fff'
                        PID         = $_.OwningProcess
                        Process     = $proc.Name
                        Local       = "$($_.LocalAddress):$($_.LocalPort)"
                        Remote      = "$($_.RemoteAddress):$($_.RemotePort)"
                        ReverseDNS  = $rdns
                        State       = $_.State
                    } | Format-Table -AutoSize
                }
            }

    Start-Sleep -Milliseconds $sampleMs
}

Write-Host ""
Write-Host "DNS cache entries containing rage/rgsvc/cdn/update:"
Get-DnsClientCache |
    Where-Object { $_.Entry -match 'rage|rgsvc|cdn|update' } |
    Select-Object Entry, Data, Type, Status |
    Sort-Object Entry, Data |
    Format-Table -AutoSize -Wrap

Write-Host ""
Write-Host "End: $(Get-Date -Format o)"
