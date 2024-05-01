$ErrorActionPreference = 'Stop'

# 1) Domains that belong to Microsoft but are not whitelisted
# 2) Domains possibly belong to Microsoft but got blocked
# 3) All contacted domains, excluding the domains stored in other Microsoft related lists and blocked domains
foreach ($File in 'NotWhitelisted.txt', 'MicrosoftPossibleBlocked.txt', 'AllDomains.txt') {
    if (-NOT (Test-Path -Path ".\$File")) {
        New-Item -ItemType File -Path ".\$File" -Force | Out-Null
    }
}

# a file to store all of the domains that were connected to, with their counts as a hashtable. Excluding the domains stored in other Microsoft related lists and blocked domains
if (-NOT (Test-Path -Path .\AllDomainsCount.txt)) {
    New-Item -ItemType File -Path .\AllDomainsCount.txt -Force | Out-Null
    # Create an empty ordered hashtable to store the domains and their counts
    $DomainCount = [System.Management.Automation.OrderedHashtable]::new()
}
# If the file already exists, convert it to JSON and read it as hashtable
else {
    [System.Management.Automation.OrderedHashtable]$DomainCount = Get-Content -Path '.\AllDomainsCount.txt' | ConvertFrom-Json -AsHashtable
}

# a file to store all of the blocked domains that were connected to, with their counts as a hashtable
if (-NOT (Test-Path -Path .\AllBlockedCount.txt)) {
    New-Item -ItemType File -Path .\AllBlockedCount.txt -Force | Out-Null
    $BlockedCount = [System.Management.Automation.OrderedHashtable]::new()
}
# If the file already exists, convert it to JSON and read it as hashtable
else {
    [System.Management.Automation.OrderedHashtable]$BlockedCount = Get-Content -Path '.\AllBlockedCount.txt' | ConvertFrom-Json -AsHashtable
}

# Try-Finally to loop through the stream and process each line as a JSON object
try {

    # Read the Whitelisted Domains, it's always located here: https://github.com/HotCakeX/MicrosoftDomains/blob/main/Microsoft%20Domains.txt
    $WhiteListedDomains = [System.Collections.Generic.HashSet[System.String]] @(Get-Content -Path '.\Microsoft Domains.txt')

    # Define the API key and the profile ID to access the NextDNS API - https://my.nextdns.io/account
    [System.String]$ApiKey = ''
    [System.String]$ProfileId = ''

    # Define the endpoint that you need to send a web request to get the logs as a SSE stream - https://nextdns.github.io/api/#streaming
    [System.Uri]$URL = "https://api.nextdns.io/profiles/$ProfileId/logs/stream"

    # Create an empty NameValueCollection
    # This is a special type of collection that can store multiple values for each key, and it is used by the web request object to set the header
    $HeaderNVC = [System.Collections.Specialized.NameValueCollection]::new()

    # Add the X-Api-Key header for authentication to the NameValueCollection
    $HeaderNVC.Add('X-Api-Key', $ApiKey)

    # Create a web request object that represents a HTTP request that can be sent to a server and get a response
    $WebRequest = [System.Net.HttpWebRequest]::Create($URL)

    # Adding the header to the web request object
    $WebRequest.Headers.Add($HeaderNVC)

    # Set the timeout to infinite, tells the web request object to wait indefinitely for a response, because we are expecting a continuous stream of data from the server
    $WebRequest.Timeout = -1

    # Get the web response (HTTP response) object from the server
    [System.Net.HttpWebResponse]$Response = $WebRequest.GetResponse()

    # Get the response stream, represents a stream of data that is sent by the server as part of the response, and it can be read line by line using a stream reader object
    $ResponseStream = $Response.GetResponseStream()

    # Create a stream reader object that can read data from a stream, such as the response stream, and convert it to text
    $StreamReader = [System.IO.StreamReader]::new($ResponseStream)

    while ($true) {
        # Read one line from the stream, which corresponds to one event from the server
        $Line = $StreamReader.ReadLine()

        # Split the line by colon and space characters
        # This is a way of separating the line into two parts: the prefix (id: or data:) and the JSON data. We use colon and space as delimiters, and limit the number of parts to 2.
        $Parts = $Line.Split(': ', 2)

        # Check if the line has two parts
        # This is a way of validating that the line has both a prefix and a JSON data, and not something else. We use the Count property of the array to check this.
        if ($Parts.Count -eq 2) {
            # Use the second part so we only get the JSON data from the line (index 0 is for prefix)
            $JsonData = $Parts[1]

            # Check if the JSON data is not empty
            if ($JsonData -ne '') {

                # Remove any characters from the beginning of the JSON data that may make it invalid or malformed such as colon or space
                $JsonData = $JsonData.TrimStart(': ')

                # Test if the JSON data is a valid JSON object using the Test-Json cmdlet
                [System.Boolean]$IsValidJson = Test-Json -Json $JsonData -ErrorAction SilentlyContinue

                # Check if the JSON data is a valid JSON object
                if ($IsValidJson) {

                    # Convert the JSON data to a hashtable
                    [System.Management.Automation.OrderedHashtable]$Log = $JsonData | ConvertFrom-Json -AsHashtable

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
                            $CurrentItemsMicrosoft = [System.Collections.Generic.HashSet[System.String]] @(Get-Content -Path '.\MicrosoftPossibleBlocked.txt' -Force)

                            # Add the Blocked domain to the MicrosoftPossibleBlocked.txt list for later review
                            if (-NOT $CurrentItemsMicrosoft.Contains($RootDomain)) {
                                Add-Content -Value $RootDomain -Path '.\MicrosoftPossibleBlocked.txt' -Force
                            }
                        }
                        # If the domain was not blocked but also wasn't in the Microsoft domains Whitelist
                        elseif (-NOT $WhiteListedDomains.Contains($RootDomain)) {

                            # Display it with cyan text on the console
                            Write-Host -Object 'Microsoft Domain Not Whitelisted' -ForegroundColor Cyan
                            $($Log | Select-Object -Property timestamp, domain, root, clientIp, status | Format-Table)

                            # Make sure the domain isn't already available in the NotWhitelisted.Txt file
                            $CurrentItemsNotWhitelisted = [System.Collections.Generic.HashSet[System.String]] @(Get-Content -Path '.\NotWhitelisted.txt' -Force)

                            # Add the detected domain to the NotWhitelisted.Txt list for later review
                            if (-NOT $CurrentItemsNotWhitelisted.Contains($RootDomain)) {
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

                        # Check if the domain already exists in the blocked domains hashtable
                        if ($BlockedCount.ContainsKey($RootDomain)) {
                            # Increment its count by one
                            $BlockedCount[$RootDomain] += 1
                        }
                        else {
                            # Add it to the hashtable with a count of one
                            $BlockedCount.Add($RootDomain, 1)
                        }

                        # Convert the hashtable to a JSON string and write it to .\AllBlockedCount.txt
                        $BlockedCount | ConvertTo-Json | Set-Content -Path '.\AllBlockedCount.txt' -Force
                    }
                    # Display any allowed domain with green text on the console
                    else {
                        Write-Host -Object 'Allowed' -ForegroundColor Green
                        $($Log | Select-Object -Property timestamp, domain, root, clientIp, status | Format-Table)

                        # if the domain is neither blocked, belongs to Microsoft nor is it in the whitelisted domains list
                        if (-NOT $WhiteListedDomains.Contains($RootDomain)) {

                            $CurrentItemsAllDomains = [System.Collections.Generic.HashSet[System.String]] @(Get-Content -Path '.\AllDomains.txt' -Force)

                            # Add the domain to .\AllDomains.txt , make sure it's unique and not already in the list
                            if (-NOT $CurrentItemsAllDomains.Contains($RootDomain)) {
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
    $_
}
finally {
    # If an error occurred while reading from the stream
    Write-Error -Message "An error occurred while reading from the stream: $_" -ErrorAction Continue

    # Add cool down timer for restarting the script

    # If it's the first time error is thrown
    if (!$WaitSeconds) {
        [System.Int16]$WaitSeconds = 3
    }
    # if it's not the first time error is thrown
    else {
        if ($WaitSeconds -ge 20) {
            $WaitSeconds = 3
        }
        else {
            $WaitSeconds++
        }
    }

    Write-Error -Message "Restarting the script in $WaitSeconds seconds..." -ErrorAction Continue

    # Close and dispose of the stream reader, response stream, and web response objects
    try {
        $StreamReader.Close()
        $StreamReader.Dispose()
        $ResponseStream.Close()
        $ResponseStream.Dispose()
        $Response.Close()
    }
    catch {}

    Start-Sleep -Seconds $WaitSeconds

    # Restart using & operator - Runs the script again using its path
    & $PSCommandPath
}
