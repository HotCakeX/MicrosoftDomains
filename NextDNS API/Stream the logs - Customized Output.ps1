# Make a new file to store the items that belong to Microsoft but are not in the Whitelisted domains list
if (-NOT (Test-Path .\NotWhitelisted.txt)) {
    New-Item -ItemType File -Path .\NotWhitelisted.txt -Force | Out-Null
}

# Make a new file to store the items that possibly belong to Microsoft but got blocked
if (-NOT (Test-Path .\MicrosoftPossibleBlocked.txt)) {
    New-Item -ItemType File -Path .\MicrosoftPossibleBlocked.txt -Force | Out-Null
}

# Make a new file to store all of the domains that were connected to, no duplicates
if (-NOT (Test-Path .\AllDomains.txt)) {
    New-Item -ItemType File -Path .\AllDomains.txt -Force | Out-Null
}

# Try to loop through the stream and process each line as a JSON object
# Use -ErrorAction Stop to report errors as exceptions
try {

    # Read the Whitelisted Domains
    $WhiteListedDomains = Get-Content -Path "E:\Cloned Repositories\MicrosoftDomains\Microsoft Domains.txt"

    # Define the API key and the profile ID
    # These are the credentials that you need to access the NextDNS API
    # Get your API key from here: https://my.nextdns.io/account
    $ApiKey = ""
    $ProfileId = ""

    # Define the URL for streaming the logs
    # This is the endpoint that you need to send a web request to get the logs as a SSE stream
    # https://nextdns.github.io/api/#streaming
    $url = "https://api.nextdns.io/profiles/$ProfileId/logs/stream"

    # Create a header with the API key as a hashtable
    # This is a key-value pair that you need to include in the web request to authenticate yourself
    $Header = @{
        "X-Api-Key" = $ApiKey
    }


    # Create an empty NameValueCollection
    # This is a special type of collection that can store multiple values for each key, and it is used by the web request object to set the header
    $HeaderNVC = [System.Collections.Specialized.NameValueCollection]::new()

    # Loop over the hashtable keys and values and add them to the NameValueCollection
    # This is a way of converting the hashtable to a NameValueCollection, by iterating over each key and value and adding them to the collection
    foreach ($key in $Header.Keys) {
        $Value = $Header[$key]
        $HeaderNVC.Add($key, $Value)
    }

    # Create a web request object
    # This is an object that represents a HTTP request that can be sent to a server and get a response
    $WebRequest = [System.Net.HttpWebRequest]::Create($url)

    # Set the header with the API key
    # This is a way of adding the header to the web request object, by using the NameValueCollection that we created earlier
    $WebRequest.Headers.Add($HeaderNVC)

    # Set the timeout to infinite
    # This is a way of telling the web request object to wait indefinitely for a response, because we are expecting a continuous stream of data from the server
    $WebRequest.Timeout = -1

    # Get the web response object
    # This is an object that represents a HTTP response that is received from the server after sending the web request
    $Response = $WebRequest.GetResponse()

    # Get the response stream
    # This is an object that represents a stream of data that is sent by the server as part of the response, and it can be read line by line using a stream reader object
    $ResponseStream = $Response.GetResponseStream()

    # Create a stream reader object
    # This is an object that can read data from a stream, such as the response stream, and convert it to text
    $StreamReader = [System.IO.StreamReader]::new($ResponseStream)

    # while (-not $StreamReader.EndOfStream) {
    while ($true) {
        # Read one line from the stream
        # This is a way of getting one line of text from the stream reader object, which corresponds to one event from the server
        $Line = $StreamReader.ReadLine()

        # Split the line by colon and space characters
        # This is a way of separating the line into two parts: the prefix (id: or data:) and the JSON data. We use colon and space as delimiters, and limit the number of parts to 2.
        $parts = $Line.Split(': ', 2)

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
                $IsValidJson = Test-Json $jsonData -ErrorAction SilentlyContinue
        
                # Check if the JSON data is a valid JSON object
                # This is a way of validating that the Test-Json cmdlet returned true, and not false or an error. We use an if statement to check this.
                if ($IsValidJson) {
                    # Convert the JSON data to a hashtable
                    # This is a way of parsing the JSON data as a JSON object, and converting it to a hashtable, which is a key-value pair collection that is easier to work with in PowerShell. We use the ConvertFrom-Json cmdlet with the -AsHashtable parameter to do this.
                    $Log = $jsonData | ConvertFrom-Json -AsHashtable
        
                    # Select only the properties that you are interested in
                    # This is a way of filtering the hashtable and getting only the properties that you want, such as timestamp, domain, root, encrypted, protocol, clientIp, status. We use the Select-Object cmdlet with the property names to do this.
                    # $Log = $Log | Select-Object timestamp, domain, root, clientIp, status | Format-Table
              
                    # Making sure the root in the log is actually the root domain and not a sub-domain
                    # Sometimes it identifies sub-domains as root domains, so here we make sure it doesn't happen
                    # first see if the root domain has more than 1 dot in it, indicating that it contains sub-domains
                    if ($Log.root -like '*.*.*') {
                        # Define a regex pattern that starting from the end, captures everything until the 2nd dot
                        if ($Log.root -match '(?s).*\.(.+?\..+?)$') {
                            
                            $rootDomain = $matches[1]

                            Write-Host "$rootDomain is Regex cleared" -ForegroundColor Yellow
                        }
                    }

                    # if the root domain doesn't have more than 1 dot then no need to change it, assign it as is
                    else {
                        $rootDomain = $Log.root

                        Write-Host "$rootDomain is OK" -ForegroundColor Magenta
                    }
                       

                    # If the root domain's name resembles Microsoft domain names
                    if ($rootDomain -like "*msft*" `
                            -or $rootDomain -like "*microsoft*" `
                            -or $rootDomain -like "*bing*" `
                            -or $rootDomain -like "*xbox*" `
                            -or $rootDomain -like "*azure*" `
                            -or $rootDomain -like "*.ms*" 
                    ) {
                        # If the domain was blocked
                        if ($Log.status -eq 'blocked') {
                            # Display it with yellow text on the host
                            Write-Host "Microsoft BLOCKED" -ForegroundColor Yellow
                            $($Log | Select-Object timestamp, domain, root, clientIp, status | Format-Table) 

                            # Make sure the domain isn't already available in the file
                            $CurrentItemsMicrosoft = Get-Content -Path '.\MicrosoftPossibleBlocked.txt'

                            # Add the Blocked domain to the MicrosoftPossibleBlocked.txt list for later review
                            if ($rootDomain -notin $CurrentItemsMicrosoft) {
                                Add-Content -Value $rootDomain -Path '.\MicrosoftPossibleBlocked.txt'
                            }
                        }
                        # If the domain was not blocked but also wasn't in the Microsoft domains Whitelist                     
                        elseif ($rootDomain -notin $WhiteListedDomains) {                    
                            # Display it with cyan text on the host
                            Write-Host "Microsoft Domain Not Whitelisted" -ForegroundColor Cyan
                            $($Log | Select-Object timestamp, domain, root, clientIp, status | Format-Table)
               
                            # Make sure the domain isn't already available in the NotWhitelisted.Txt file
                            $CurrentItemsNotWhitelisted = Get-Content -Path '.\NotWhitelisted.txt'

                            # Add the detected domain to the NotWhitelisted.Txt list for later review
                            if ($rootDomain -notin $CurrentItemsNotWhitelisted) {
                                Add-Content -Value $rootDomain -Path '.\NotWhitelisted.txt'
                            }
                        }
                        else {
                            # Display the allowed Microsoft domain with green text on the host
                            Write-Host "Allowed" -ForegroundColor Green
                            $($Log | Select-Object timestamp, domain, root, clientIp, status | Format-Table)  
                        }
                    }
                    # Display any blocked domain with red text on the host
                    elseif ($Log.status -eq 'blocked') {
                        Write-Host "BLOCKED" -ForegroundColor Red
                        $($Log | Select-Object timestamp, domain, root, clientIp, status | Format-Table)        
                    }
                    # Display any allowed domain with green text on the host
                    else {                        
                        Write-Host "Allowed" -ForegroundColor Green
                        $($Log | Select-Object timestamp, domain, root, clientIp, status | Format-Table) 
                        
                        # if the domain is neither blocked, belongs to Microsoft nor is it in the whitelisted domains list
                        if ($rootDomain -notin $WhiteListedDomains) {

                            # Get the content of the .\AllDomains.txt
                            $CurrentItemsAllDomains = Get-Content -Path '.\AllDomains.txt'

                            # Add the domain to .\AllDomains.txt , make sure it's unique and not already in the list
                            if ($rootDomain -notin $CurrentItemsAllDomains) {
                                Add-Content -Value $rootDomain -Path '.\AllDomains.txt'
                            }
                        }
                    }                     
                }
            }
        }
    }
}
catch {
    # Catch any exception that occurs in the try block
    # Write an error message to indicate what happened
    Write-Error "An error occurred while reading from the stream: $_"

    # Restart the script using $PSCommandPath and &
    Write-Host "Restarting script..."
    & $PSCommandPath
}
finally {
    # Execute some cleanup actions after exiting the try or catch block
    # Close and dispose of the stream reader, response stream, and web response objects
    $StreamReader.Close()
    $StreamReader.Dispose()
    $ResponseStream.Close()
    $ResponseStream.Dispose()
    $Response.Close()
}
        