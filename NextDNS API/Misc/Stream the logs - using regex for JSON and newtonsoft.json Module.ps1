# Define the API key and the profile ID
$apiKey = ''
$profileId = ''

# Define the URL for streaming the logs
# https://nextdns.github.io/api/#streaming
$url = "https://api.nextdns.io/profiles/$profileId/logs/stream"

# Create a header with the API key as a hashtable
$header = @{
    'X-Api-Key' = $apiKey
}

# Create an empty NameValueCollection
$headerNVC = [System.Collections.Specialized.NameValueCollection]::new()

# Loop over the hashtable keys and values and add them to the NameValueCollection
foreach ($key in $header.Keys) {
    $value = $header[$key]
    $headerNVC.Add($key, $value)
}

# Create a web request object
$webrequest = [System.Net.HttpWebRequest]::Create($url)

# Set the header with the API key
$webrequest.Headers.Add($headerNVC)

# Set the timeout to infinite
$webrequest.Timeout = -1

# Get the web response object
$response = $webrequest.GetResponse()

# Get the response stream
$responseStream = $response.GetResponseStream()

# Create a stream reader object
$streamReader = [System.IO.StreamReader]::new($responseStream)

# Import the Newtonsoft.Json library
Import-Module newtonsoft.json

# Define a custom function to test the JSON validity
function Test-JsonCustom {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Json
    )

    # Try to parse the JSON string using Newtonsoft.Json library
    try {
        $result = [Newtonsoft.Json.JsonConvert]::DeserializeObject($Json)
        return $true
    }
    catch {
        return $false
    }
}

# Loop through the stream and process each line as a JSON object
while (-not $streamReader.EndOfStream) {
    # Read one line from the stream
    $line = $streamReader.ReadLine()

    # Remove the prefix from the line
    $line = $line -replace '^(id|data): '

    # Check if the line is not empty
    if ($line -ne '') {
        # Test if the line is a valid JSON object using the custom function
        $isValidJson = Test-JsonCustom $line

        # Check if the line is a valid JSON object
        if ($isValidJson) {
            # Convert the line to a hashtable
            $log = $line | ConvertFrom-Json -AsHashtable

            # Select only the properties that you are interested in
            $log = $log | Select-Object timestamp, domain, root, encrypted, protocol, clientIp, status

            # Do something with the log object, such as displaying it or filtering it
            Write-Output $log
        }
    }
}

# Close the response and the stream
$response.Close()
$responseStream.Close()
