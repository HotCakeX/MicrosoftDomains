# Get the Microsoft domains from GitHub
[Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]$MicrosoftDomainsRaw = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/HotCakeX/MicrosoftDomains/main/Microsoft%20Domains.txt'

# Extract the domains from the response - removing the empty lines
$MicrosoftDomains = [System.Collections.Generic.HashSet[System.String]] @($MicrosoftDomainsRaw.Content -split '\n' | Where-Object -FilterScript { -NOT ([System.String]::IsNullOrEmpty($_)) })

Write-Host -Object "$($MicrosoftDomains.Count) domains available on GitHub" -ForegroundColor Magenta

# Get your API key from here: https://my.nextdns.io/account
[System.Collections.Hashtable]$NextDNSAccounts = @{
    'YourAccount' = @{
        ApiKey    = 'YOUR_API_KEY_HERE'
        ProfileID = 'YOUR_PROFILE_ID_HERE'
    }
}

foreach ($Account in $NextDNSAccounts.GetEnumerator()) {

    # Creating the header with the API key
    [System.Collections.Hashtable]$Header = @{
        'X-Api-Key'    = $Account.Value['ApiKey']
        'Content-Type' = 'application/json'
    }

    # Send the GET request to the API endpoint to get the allowlist
    [System.Object]$AllowListRaw = Invoke-RestMethod -Method 'Get' -Uri "https://api.nextdns.io/profiles/$($Account.Value['ProfileID'])/allowlist" -Headers $Header

    # Extract the domains from response - removing the empty lines
    $AllowList = [System.Collections.Generic.HashSet[System.String]] @($AllowListRaw.data.id | Where-Object -FilterScript { -NOT ([System.String]::IsNullOrEmpty($_)) })

    Write-Host -Object "$($AllowList.Count) domain(s) available in the NextDNS Allowlist of the account $($Account.Name)" -ForegroundColor Cyan

    # Compare the two lists
    $DomainsNotInAllowList = [System.Collections.Generic.HashSet[System.String]] @($MicrosoftDomains | Where-Object -FilterScript { -NOT ($AllowList.Contains($_)) })

    Write-Host -Object "$($DomainsNotInAllowList.Count) domain(s) are not in the allowlist of the account $($Account.Name)" -ForegroundColor Yellow

    # Utilisation de la fonction Write-Progress intégrée à PowerShell
    $totalDomains = $DomainsNotInAllowList.Count
    $currentDomain = 0
    
    # Loop through the domains that are not in the allowlist
    foreach ($Domain in $DomainsNotInAllowList) {
        $currentDomain++
        
        # Mise à jour de la barre de progression native PowerShell
        Write-Progress -Activity "Ajout des domaines à la liste d'autorisation" -Status "Progression: $currentDomain sur $totalDomains" -PercentComplete (($currentDomain / $totalDomains) * 100)

        # Create the body with the domain id
        [System.Collections.Hashtable]$Body = @{
            'id' = $Domain
        }

        # Convert the body to JSON format
        [System.String]$JsonBody = $Body | ConvertTo-Json

        # Pas besoin d'effacer avec Write-Progress
        Write-Host -Object "Adding $Domain to the allowlist for the account $($Account.Name)" -ForegroundColor White

        # Variable pour suivre si l'opération a réussi
        $success = $false
        $retryCount = 0

        while (-not $success) {
            try {
                # Send the POST request to the API endpoint to add the domain to the allowlist in the NextDNS profile
                Invoke-RestMethod -Method Post -Uri "https://api.nextdns.io/profiles/$($Account.Value['ProfileID'])/allowlist" -Headers $Header -Body $JsonBody | Out-Null
                $success = $true
                Write-Host -Object "Successfully added $Domain to the allowlist" -ForegroundColor Green
            }
            catch {
                $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                # Check if the error is due to rate limiting
                if ($errorDetails.errors -and $errorDetails.errors[0].code -eq "rateLimit") {
                    $retryCount++
                    $waitTime = [math]::Pow(2, $retryCount) # Exponential backoff: 2, 4, 8, 16, 32 seconds...
                    Write-Host -Object "Rate limit hit. Waiting for $waitTime seconds before retry..." -ForegroundColor Cyan
                    Start-Sleep -Seconds $waitTime
                }
                else {
                    # For other types of errors, log and continue
                    Write-Host -Object "Error adding $Domain to the allowlist: $_" -ForegroundColor Red
                    $success = $true # Marquer comme réussi pour éviter une boucle infinie sur d'autres types d'erreurs
                    break
                }
            }
        }

        # Add a small delay between requests to avoid hitting rate limits
        Start-Sleep -Milliseconds 500
        
        # Mise à jour de la progression (facultatif car déjà fait au début de la boucle)
        Write-Progress -Activity "Ajout des domaines à la liste d'autorisation" -Status "Progression: $currentDomain sur $totalDomains" -PercentComplete (($currentDomain / $totalDomains) * 100)
    }
}

