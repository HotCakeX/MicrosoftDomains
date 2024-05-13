# Get the Microsoft domains from GitHub
[Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]$MicrosoftDomainsRaw = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/HotCakeX/MicrosoftDomains/main/Microsoft%20Domains.txt'

# Extract the domains from the response - removing the empty lines
$MicrosoftDomains = [System.Collections.Generic.HashSet[System.String]] @($MicrosoftDomainsRaw.Content -split '\n' | Where-Object -FilterScript { -NOT ([System.String]::IsNullOrEmpty($_)) })

Write-Host -Object "$($MicrosoftDomains.Count) domains available on GitHub" -ForegroundColor Magenta

# Get your API key from here: https://my.nextdns.io/account
[System.Collections.Hashtable]$NextDNSAccounts = @{
    'Account1' = @{
        ApiKey    = ''
        ProfileID = ''
    }
    'Account2' = @{
        ApiKey    = ''
        ProfileID = ''
    }
    # Add more as accounts as needed
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

    # Loop through the domains that are not in the allowlist
    foreach ($Domain in $DomainsNotInAllowList) {

        # Create the body with the domain id
        [System.Collections.Hashtable]$Body = @{
            'id' = $Domain
        }

        # Convert the body to JSON format
        [System.String]$JsonBody = $Body | ConvertTo-Json

        Write-Host -Object "Adding $Domain to the allowlist for the account $($Account.Name)" -ForegroundColor Green

        # Send the POST request to the API endpoint to add the domain to the allowlist in the NextDNS profile
        Invoke-RestMethod -Method Post -Uri "https://api.nextdns.io/profiles/$($Account.Value['ProfileID'])/allowlist" -Headers $Header -Body $JsonBody | Out-Null
    }
}
