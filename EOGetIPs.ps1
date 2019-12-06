<#
Found here: https://www.reddit.com/r/PowerShell/comments/8h2ie6/going_thru_365_logs_for_foreign_ips/
Credit goes to u/chugger93 and u/purplemonkeymad (Correct me if I missed anyone)
Made a few changes, mainly to deal with the api throttling. Just buy an account.DESCRIPTION
I plan on making a function based on this script.DESCRIPTION
#>

$startDate = (Get-Date).AddDays(-1) #If you set this to far into the past you're going to have a bad time.
$endDate = (Get-Date)
$Logs = @()
Write-Host "Retrieving logs" -ForegroundColor Blue
do {
    $logs += Search-unifiedAuditLog -SessionCommand ReturnLargeSet -SessionId "UALSearch" -ResultSize 5000 -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn
    Write-Host "Retrieved $($logs.count) logs" -ForegroundColor Yellow
} while ($Logs.count % 5000 -eq 0 -and $logs.count -ne 0)
Write-Host "Finished Retrieving logs" -ForegroundColor Green

$userIds = $logs.userIds | Sort-Object -Unique

$GeoIPCache = @{}

$Results = foreach ($userId in $userIds) {

    $ips = @()
    Write-Host "Getting logon IPs for $userId"
    $searchResult = ($logs | Where-Object {$_.userIds -contains $userId}).auditdata | ConvertFrom-Json -ErrorAction SilentlyContinue
    Write-Host "$userId has $($searchResult.count) logs" -ForegroundColor Green

    $ips = $searchResult.clientip | Sort-Object -Unique
    Write-Host "Found $($ips.count) unique IP addresses for $userId"
    foreach ($ip in $ips) {
        Write-Host "Checking $ip" -ForegroundColor Yellow
        $mergedObject = @{}
        $singleResult = $searchResult | Where-Object {$_.clientip -contains $ip} | Select-Object -First 1
        Start-sleep -m 400
        $ipresult = if ($GeoIPCache[$ip] ){
            $GeoIPCache[$ip]
        } else {
            try {
              $APICall = Invoke-restmethod -method get -uri http://ip-api.com/json/$ip
            } catch {
              write-host "Throttled. Sleeping for 80 seconds and trying again."
              start-sleep -s 80
              $APICall = Invoke-restmethod -method get -uri http://ip-api.com/json/$ip
            }
            $GeoIPCache[$ip] = $APICall
            $APICall
        }
        $UserAgent = $singleResult.extendedproperties.value[0]
        Write-Host "Country: $($ipResult.country) UserAgent: $UserAgent"
        $singleResultProperties = $singleResult | Get-Member -MemberType NoteProperty
        foreach ($property in $singleResultProperties) {
            if ($property.Definition -match "object") {
                $string = $singleResult.($property.Name) | ConvertTo-Json -Depth 10
                $mergedObject | Add-Member -Name $property.Name -Value $string -MemberType NoteProperty
            }
            else {$mergedObject | Add-Member -Name $property.Name -Value $singleResult.($property.Name) -MemberType NoteProperty}
        }
        $property = $null
        $ipProperties = $ipresult | get-member -MemberType NoteProperty

        foreach ($property in $ipProperties) {
            $mergedObject | Add-Member -Name $property.Name -Value $ipresult.($property.Name) -MemberType NoteProperty | sort-object country
        }
        $mergedObject | Select-Object UserId, Operation, CreationTime, Query, City, RegionName, Country, @{Name = "UserAgent"; Expression = {$UserAgent}}
    }
}
$Results | export-csv UserLocationDataGCITS.csv -Append -NoTypeInformation
