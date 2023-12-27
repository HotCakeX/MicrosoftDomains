# Make a new file to store the items that belong to Microsoft but are not in the Whitelisted domains list
if (-NOT (Test-Path -Path .\NotWhitelisted.txt)) {
    New-Item -ItemType File -Path .\NotWhitelisted.txt -Force | Out-Null
}

# Make a new file to store the items that possibly belong to Microsoft but got blocked
if (-NOT (Test-Path -Path .\MicrosoftPossibleBlocked.txt)) {
    New-Item -ItemType File -Path .\MicrosoftPossibleBlocked.txt -Force | Out-Null
}

# Make a new file to store all of the domains that were connected to, no duplicates. Excluding the domains stored in other Microsoft related lists and blocked domains
if (-NOT (Test-Path -Path .\AllDomains.txt)) {
    New-Item -ItemType File -Path .\AllDomains.txt -Force | Out-Null
}

# Make a new file to store all of the domains that were connected to, with their counts as a hashtable. Excluding the domains stored in other Microsoft related lists and blocked domains
if (-NOT (Test-Path -Path .\AllDomainsCount.txt)) {
    New-Item -ItemType File -Path .\AllDomainsCount.txt -Force | Out-Null

    # Create an empty ordered hashtable to store the domains and their counts
    $DomainCount = [System.Management.Automation.OrderedHashtable]::new()
}
# If the file and hashtable already exists, read it
else {
    # Read the JSON string from the file and convert it to a hashtable
    [System.Management.Automation.OrderedHashtable]$DomainCount = Get-Content -Path '.\AllDomainsCount.txt' | ConvertFrom-Json -AsHashtable
}

# Try to loop through the stream and process each line as a JSON object
# Use -ErrorAction Stop to report errors as exceptions
try {

    # Read the Whitelisted Domains, it's always located here: https://github.com/HotCakeX/MicrosoftDomains/blob/main/Microsoft%20Domains.txt
    [System.String[]]$WhiteListedDomains = Get-Content -Path '.\Microsoft Domains.txt'

    # Define the API key and the profile ID
    # These are the credentials that you need to access the NextDNS API
    # Get your API key from here: https://my.nextdns.io/account
    [System.String]$ApiKey = ''
    [System.String]$ProfileId = ''

    # Define the URL for streaming the logs
    # This is the endpoint that you need to send a web request to get the logs as a SSE stream
    # https://nextdns.github.io/api/#streaming
    [System.Uri]$URL = "https://api.nextdns.io/profiles/$ProfileId/logs/stream"

    # Create a header with the API key as a hashtable
    # This is a key-value pair that you need to include in the web request to authenticate yourself
    [System.Collections.Hashtable]$Header = @{
        'X-Api-Key' = $ApiKey
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
    $WebRequest = [System.Net.HttpWebRequest]::Create($URL)

    # Set the header with the API key
    # This is a way of adding the header to the web request object, by using the NameValueCollection that we created earlier
    $WebRequest.Headers.Add($HeaderNVC)

    # Set the timeout to infinite
    # This is a way of telling the web request object to wait indefinitely for a response, because we are expecting a continuous stream of data from the server
    $WebRequest.Timeout = -1

    # Get the web response object
    # This is an object that represents a HTTP response that is received from the server after sending the web request
    [System.Net.HttpWebResponse]$Response = $WebRequest.GetResponse()

    # Get the response stream
    # This is an object that represents a stream of data that is sent by the server as part of the response, and it can be read line by line using a stream reader object
    $ResponseStream = $Response.GetResponseStream()

    # Create a stream reader object
    # This is an object that can read data from a stream, such as the response stream, and convert it to text
    $StreamReader = [System.IO.StreamReader]::new($ResponseStream)

    while ($true) {
        # Read one line from the stream
        # This is a way of getting one line of text from the stream reader object, which corresponds to one event from the server
        $Line = $StreamReader.ReadLine()

        # Split the line by colon and space characters
        # This is a way of separating the line into two parts: the prefix (id: or data:) and the JSON data. We use colon and space as delimiters, and limit the number of parts to 2.
        $Parts = $Line.Split(': ', 2)

        # Check if the line has two parts
        # This is a way of validating that the line has both a prefix and a JSON data, and not something else. We use the Count property of the array to check this.
        if ($Parts.Count -eq 2) {
            # Use the second part as the JSON data
            # This is a way of getting only the JSON data from the line, by using index 1 of the array (index 0 is for prefix)
            $JsonData = $Parts[1]

            # Check if the JSON data is not empty
            # This is a way of validating that there is some data in the JSON part, and not just an empty string. We use the -ne operator to compare the JSON data with an empty string.
            if ($JsonData -ne '') {

                # Remove any characters from the beginning of the JSON data that may make it invalid or malformed
                # This is a way of fixing the JSON data if it has some extra characters at the beginning, such as colon or space, that may prevent it from being parsed as a JSON object.
                $JsonData = $JsonData.TrimStart(': ')

                # Test if the JSON data is a valid JSON object using the Test-Json cmdlet
                # This is a way of checking if the JSON data can be parsed as a JSON object. We use the -ErrorAction SilentlyContinue parameter to suppress any error messages and return false instead.
                $IsValidJson = Test-Json -Json $JsonData -ErrorAction SilentlyContinue

                # Check if the JSON data is a valid JSON object
                if ($IsValidJson) {

                    # Convert the JSON data to a hashtable
                    # This is a way of parsing the JSON data as a JSON object, and converting it to a hashtable
                    [System.Management.Automation.OrderedHashtable]$Log = $JsonData | ConvertFrom-Json -AsHashtable

                    # Select only the properties that you are interested in
                    # This is a way of filtering the hashtable and getting only the properties that you want, such as timestamp, domain, root, encrypted, protocol, clientIp, status. We use the Select-Object cmdlet with the property names to do this.
                    # $Log = $Log | Select-Object timestamp, domain, root, clientIp, status | Format-Table

                    # Making sure the root in the log is actually the root domain and not a sub-domain
                    # Sometimes it identifies sub-domains as root domains, so here we make sure it doesn't happen
                    # first see if the root domain has more than 1 dot in it, indicating that it contains sub-domains
                    if ($Log.root -like '*.*.*') {
                        # Define a regex pattern that starts from the end (rightmost side), captures everything until the 2nd dot (goes towards the left)
                        if ($Log.root -match [System.Text.RegularExpressions.Regex]'(?<BadRoot>(?s).*\.(?<RealRoot>.+?\..+?)$)') {
                            
                            # If NextDNS didn't properly provide the correct root domain, check if it contains any of these sub-TLDs
                            # If it does then select the entire string
                            if ($Matches.BadRoot -match [System.Text.RegularExpressions.Regex]'(?<SubTLD>co|ac|com|uk|eu|app|org|net)[.](?<TLD>.*)$') {

                                [System.String]$RootDomain = $Matches.BadRoot

                                Write-Host -Object "Sub-TLD detected in $RootDomain, applying the appropriate filters." -ForegroundColor Magenta
                            }

                            else {
                                [System.String]$RootDomain = $Matches.RealRoot

                                Write-Host -Object "$RootDomain is Regex cleared" -ForegroundColor Yellow
                            }
                        }
                    }

                    # if the root domain doesn't have more than 1 dot then no need to change it, assign it as is
                    else {
                        [System.String]$RootDomain = $Log.root

                        Write-Host -Object "$RootDomain is OK" -ForegroundColor Magenta
                    }

                    # If the root domain's name resembles Microsoft domain names
                    if ($RootDomain -match [System.Text.RegularExpressions.Regex]'.*(msft|microsoft|bing|xbox|azure|\.ms|\.msn|edge).*') {

                        # If the domain that resembles Microsoft domain was blocked
                        if ($Log.status -eq 'blocked') {
                            # Display it with yellow text on the console
                            Write-Host -Object 'Microsoft BLOCKED' -ForegroundColor Yellow
                            $($Log | Select-Object -Property timestamp, domain, root, clientIp, status | Format-Table)

                            # Make sure the domain isn't already available in the file
                            [System.String[]]$CurrentItemsMicrosoft = Get-Content -Path '.\MicrosoftPossibleBlocked.txt' -Force

                            # Add the Blocked domain to the MicrosoftPossibleBlocked.txt list for later review
                            if ($RootDomain -notin $CurrentItemsMicrosoft) {
                                Add-Content -Value $RootDomain -Path '.\MicrosoftPossibleBlocked.txt' -Force
                            }
                        }
                        # If the domain was not blocked but also wasn't in the Microsoft domains Whitelist
                        elseif ($RootDomain -notin $WhiteListedDomains) {
                            # Display it with cyan text on the console
                            Write-Host -Object 'Microsoft Domain Not Whitelisted' -ForegroundColor Cyan
                            $($Log | Select-Object -Property timestamp, domain, root, clientIp, status | Format-Table)

                            # Make sure the domain isn't already available in the NotWhitelisted.Txt file
                            [System.String[]]$CurrentItemsNotWhitelisted = Get-Content -Path '.\NotWhitelisted.txt' -Force

                            # Add the detected domain to the NotWhitelisted.Txt list for later review
                            if ($RootDomain -notin $CurrentItemsNotWhitelisted) {
                                Add-Content -Value $RootDomain -Path '.\NotWhitelisted.txt' -Force
                            }
                        }
                        else {
                            # Display the allowed Microsoft domain with green text on the console
                            Write-Host -Object 'Allowed' -ForegroundColor Green
                            $($Log | Select-Object -Property timestamp, domain, root, clientIp, status | Format-Table)
                        }
                    }
                    # Display any blocked domain with red text on the console
                    elseif ($Log.status -eq 'blocked') {
                        Write-Host -Object 'BLOCKED' -ForegroundColor Red
                        $($Log | Select-Object -Property timestamp, domain, root, clientIp, status | Format-Table)
                    }
                    # Display any allowed domain with green text on the console
                    else {
                        Write-Host -Object 'Allowed' -ForegroundColor Green
                        $($Log | Select-Object -Property timestamp, domain, root, clientIp, status | Format-Table)

                        # if the domain is neither blocked, belongs to Microsoft nor is it in the whitelisted domains list
                        if ($RootDomain -notin $WhiteListedDomains) {

                            # Get the content of the .\AllDomains.txt
                            [System.String[]]$CurrentItemsAllDomains = Get-Content -Path '.\AllDomains.txt' -Force

                            # Add the domain to .\AllDomains.txt , make sure it's unique and not already in the list
                            if ($RootDomain -notin $CurrentItemsAllDomains) {
                                Add-Content -Value $RootDomain -Path '.\AllDomains.txt' -Force
                            }

                            # Check if the domain already exists in the hashtable
                            if ($DomainCount.ContainsKey($RootDomain)) {
                                # Increment its count by one
                                $DomainCount[$RootDomain] += 1
                            }
                            else {
                                # Add it to the hashtable with a count of one
                                $DomainCount.Add($RootDomain, 1)
                            }

                            # Convert the hashtable to a JSON string and write it to .\AllDomainsCount.txt
                            $DomainCount | ConvertTo-Json | Set-Content -Path '.\AllDomainsCount.txt' -Force
                        }
                    }
                }
            }
        }
    }
}
catch {
    # Catch any exception that occurs in the try block
    Throw "An error occurred while reading from the stream: $_"

    # Add cool down timer for restarting the script

    # If it's the first time error is thrown
    if (!$WaitSeconds) {
        $WaitSeconds = 3
    }
    # if it's not the first time error is thrown
    else {
        if ($WaitSeconds -ge 20) {
            $WaitSeconds = 3
        }
        else {
            $WaitSeconds += 1
        }
    }

    Throw "Restarting the script in $WaitSeconds seconds..."

    Start-Sleep -Seconds $WaitSeconds

    # Restart using & operator - Runs the script again using its path
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
