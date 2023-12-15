# Define the API key and the profile ID
# These are the credentials that you need to access the NextDNS API
$apiKey = ''
$profileId = ''

# Define the URL for streaming the logs
# This is the endpoint that you need to send a web request to get the logs as a SSE stream
# https://nextdns.github.io/api/#streaming
$url = "https://api.nextdns.io/profiles/$profileId/logs/stream"

# Create a header with the API key as a hashtable
# This is a key-value pair that you need to include in the web request to authenticate yourself
$header = @{
    'X-Api-Key' = $apiKey
}

# Create an empty NameValueCollection
# This is a special type of collection that can store multiple values for each key, and it is used by the web request object to set the header
$headerNVC = [System.Collections.Specialized.NameValueCollection]::new()

# Loop over the hashtable keys and values and add them to the NameValueCollection
# This is a way of converting the hashtable to a NameValueCollection, by iterating over each key and value and adding them to the collection
foreach ($key in $header.Keys) {
    $value = $header[$key]
    $headerNVC.Add($key, $value)
}

# Create a web request object
# This is an object that represents a HTTP request that can be sent to a server and get a response
$webrequest = [System.Net.HttpWebRequest]::Create($url)

# Set the header with the API key
# This is a way of adding the header to the web request object, by using the NameValueCollection that we created earlier
$webrequest.Headers.Add($headerNVC)

# Set the timeout to infinite
# This is a way of telling the web request object to wait indefinitely for a response, because we are expecting a continuous stream of data from the server
$webrequest.Timeout = -1

# Get the web response object
# This is an object that represents a HTTP response that is received from the server after sending the web request
$response = $webrequest.GetResponse()

# Get the response stream
# This is an object that represents a stream of data that is sent by the server as part of the response, and it can be read line by line using a stream reader object
$responseStream = $response.GetResponseStream()

# Create a stream reader object
# This is an object that can read data from a stream, such as the response stream, and convert it to text
$streamReader = [System.IO.StreamReader]::new($responseStream)

# Loop through the stream and process each line as a JSON object
# This is the main logic of our script, where we read each line from the stream and try to parse it as a JSON object and do something with it
while (-not $streamReader.EndOfStream) {
    # Read one line from the stream
    # This is a way of getting one line of text from the stream reader object, which corresponds to one event from the server
    $line = $streamReader.ReadLine()

    # Split the line by colon and space characters
    # This is a way of separating the line into two parts: the prefix (id: or data:) and the JSON data. We use colon and space as delimiters, and limit the number of parts to 2.
    $parts = $line.Split(': ', 2)

    # Check if the line has two parts
    # This is a way of validating that the line has both a prefix and a JSON data, and not something else. We use the Count property of the array to check this.
    if ($parts.Count -eq 2) {
        # Use the second part as the JSON data
        # This is a way of getting only the JSON data from the line, by using index 1 of the array (index 0 is for prefix)
        $jsonData = $parts[1]

        # Check if the JSON data is not empty
        # This is a way of validating that there is some data in the JSON part, and not just an empty string. We use the -ne operator to compare the JSON data with an empty string.
        if ($jsonData -ne '') {
            # Remove any characters from the beginning of the JSON data that may make it invalid or malformed
            # This is a way of fixing the JSON data if it has some extra characters at the beginning, such as colon or space, that may prevent it from being parsed as a JSON object. We use the TrimStart method to remove those characters.
            $jsonData = $jsonData.TrimStart(': ')

            # Test if the JSON data is a valid JSON object using the Test-Json cmdlet
            # This is a way of checking if the JSON data can be parsed as a JSON object, by using the Test-Json cmdlet. We use the -ErrorAction SilentlyContinue parameter to suppress any error messages and return false instead.
            $isValidJson = Test-Json $jsonData -ErrorAction SilentlyContinue

            # Check if the JSON data is a valid JSON object
            # This is a way of validating that the Test-Json cmdlet returned true, and not false or an error. We use an if statement to check this.
            if ($isValidJson) {
                # Convert the JSON data to a hashtable
                # This is a way of parsing the JSON data as a JSON object, and converting it to a hashtable, which is a key-value pair collection that is easier to work with in PowerShell. We use the ConvertFrom-Json cmdlet with the -AsHashtable parameter to do this.
                $log = $jsonData | ConvertFrom-Json -AsHashtable

                # Select only the properties that you are interested in
                # This is a way of filtering the hashtable and getting only the properties that you want, such as timestamp, domain, root, encrypted, protocol, clientIp, status. We use the Select-Object cmdlet with the property names to do this.
                # $log = $log | Select-Object timestamp, domain, root, encrypted, protocol, clientIp, status
                $log = $log | Select-Object timestamp, domain, root, clientIp, status | Format-Table

                # Do something with the log object, such as displaying it or filtering it
                # This is where you can write your own logic to process the log object, such as displaying it on the console, filtering it by some criteria, saving it to a file, etc. For this example, we just write it to the output using the Write-Output cmdlet.
                Write-Output $log
            }
        }
    }
}

# Close the response and the stream
# This is where we clean up and close the resources that we used, such as the response object and the response stream. We use the Close method to do this.
$response.Close()
$responseStream.Close()
