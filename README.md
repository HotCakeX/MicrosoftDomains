# Microsoft Domains

This repository lists all active Microsoft root domains, no URLs and no sub-domains, for the purpose of Whitelisting in various systems and apps.

This repository can facilitate the implementation of strict host-based firewall rules, for example, in a corporate environment.

It can be used to apply aggressive adblocking capabilities to your network, for example, by using NextDNS, and then use the list in this repository to apply Whitelisting.

The reason sub-domains and URLs aren't being used is that for Whitelisting we use root domain with wildcard `*`.

For example, `[*.]microsoft.com` or `[*]microsoft.com` (depending of the format your service/app supports) will allow all sub-domains and URLs under microsoft.com. This is the most efficient and maintainable way to Whitelist domains.

<br>

## How to use NextDNS API in PowerShell for Live Logs

NextDNS supports [Server-sent events (or SSE)](https://nextdns.github.io/api/#streaming), we can use it to view live stream of the logs in PowerShell, they are in JSON format.

In this [directory](https://github.com/HotCakeX/MicrosoftDomains/tree/main/NextDNS%20API) you will find the PowerShell scripts. Use the `Stream the logs - Customized Output for Microsoft.ps1` script to automatically:

1. Detect Microsoft root domains using common patterns
2. Store unique Microsoft domains that were blocked in a separate list
3. Store unique Microsoft domains that were not in the whitelist file in a separate list
4. Store unique Non-Microsoft domains in a separate list
5. Store unique Non-Microsoft domains with the number of times they were visited in a separate list
6. Display Allowed and Blocked domains on the console

<br>

## Automated GitHub workflow

The domain list is [checked](https://github.com/HotCakeX/MicrosoftDomains/actions/workflows/Duplicate%20and%20empty%20lines%20removal.yml) upon changes for duplicate entries and empty lines, and if any are found, they will be removed.

<br>

## Some of the sources

* https://learn.microsoft.com/en-us/power-platform/admin/online-requirements
* https://learn.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide
* https://learn.microsoft.com/en-us/azure/security/fundamentals/azure-domains
* https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints

<br>

## Contributing

Please feel free to contribute to this repository by creating a pull request for PowerShell scripts or domains.

### If you're adding a domain, make sure it:

1. Doesn't redirect to another domain
2. Is active and not deprecated
3. The Whois information is not private for it and explicitly states that it's owned by Microsoft
4. Not all domains are reachable when you enter them in the browser and that's understandable. If the domain you're adding is one of them, please clearly mention where and how you found it.

Thank you!
