# Define the API key and the profile ID
$apiKey = ""
$profileId = ""

# Define the URL for downloading the logs
$url = "https://api.nextdns.io/profiles/$profileId/logs"

# Create a header with the API key
$header = @{
    "X-Api-Key" = $apiKey
}

$Logs = (Invoke-WebRequest -Uri $url -Headers $header | ConvertFrom-Json)

# Display the first 10 objects
$Logs.data | Format-Table -Property timestamp,domain,root,clientip
