# Microsoft Domains

This repository lists all active Microsoft root domains, no URLs and no sub-domains, **for the purpose of Whitelisting** in various systems and apps.

This repository can facilitate the implementation of strict host-based firewall rules, for example, in a corporate environment.

It can be used to apply aggressive adblocking capabilities to your network, for example, by using NextDNS, and then **use the list in this repository to apply Whitelisting.**

The reason sub-domains and URLs aren't being used is that for Whitelisting we use root domain with wildcard `*`.

For example, `[*.]microsoft.com` or `[*]microsoft.com` (depending of the format your service/app supports) will allow all sub-domains and URLs under microsoft.com. This is the most efficient and maintainable way to Whitelist these trustworthy domains.

<br>

## How to Whitelist Microsoft Domains in Ublock Origin

<img src="https://raw.githubusercontent.com/HotCakeX/MicrosoftDomains/main/Media/Ublock%20Origin%20Config%20Whitelisting.gif" alt="How to Whitelist Microsoft Domains in Ublock Origin">

<br>

## How to Whitelist Microsoft Domains in Microsoft Edge Browser

1. Navigate to the following settings page in Edge browser: `edge://settings/content/cookies`
2. Under `Clear on exit` section, enter the following items: `http://*` and `https://*`
3. Under the `Allow` section, start adding the Microsoft domains from this repository, using this format `[*.]Microsoft.com`
4. Now every time you close your Edge browser, the cookies of the websites that are not in the *Allow* list will be removed. This can effectively increase your security and privacy on the web, without breaking websites functionalities.
5. You can optionally add any other website's domain that you don't want to log out of every time you close your browser to the list.
6. All of these settings are synced so you only have to do these once.

<br>

## How to Whitelist Microsoft Domains in NextDNS

This [PowerShell script](https://github.com/HotCakeX/MicrosoftDomains/blob/main/NextDNS%20API/Add%20Domains%20to%20the%20NextDNS%20AllowList.ps1) allows you to automatically add the Microsoft domains from this repository to the allowlist of your NextDNS profile using the API. To use this script, you need to first edit it by entering your NextDNS API key and your profile ID in it and then run it in PowerShell.

<br>

## How to use NextDNS API in PowerShell for Live Logs

NextDNS supports [Server-sent events (or SSE)](https://nextdns.github.io/api/#streaming), we can use it to view live stream of the logs in PowerShell, they are in JSON format.

In [this directory](https://github.com/HotCakeX/MicrosoftDomains/tree/main/NextDNS%20API) you will find the PowerShell scripts. Use the `Stream the logs - Customized Output for Microsoft.ps1` script to automatically:

1. Detect Microsoft root domains using common patterns (You can apply any other patterns for different purposes)
2. Store unique Microsoft domains that were blocked in a separate list
3. Store unique Microsoft domains that were not in the whitelist file in a separate list
4. Store unique Non-Microsoft domains in a separate list
5. Store unique Non-Microsoft domains with the number of times they were visited in a separate list
6. Display Allowed and Blocked domains on the console

<br>

## About The Lists

### [General List](https://github.com/HotCakeX/MicrosoftDomains/blob/main/Microsoft%20Domains.txt)

Includes the Microsoft domains that are verified to be working and owned by Microsoft or their subsidiaries.

### [Defender External Attack Surface Management (EASM)](https://github.com/HotCakeX/MicrosoftDomains/blob/main/Microsoft%20Domains%20-%20EASM.txt)

I use this [Azure service](https://azure.microsoft.com/en-us/pricing/details/defender-external-attack-surface-management/) to directly query the ISG (Intelligent Security Graph) to get the domains of Microsoft's subsidiaries. They are saved in a file called `Microsoft Domains Extra.txt` at the root of this repository. They are not manually verified by me like the general list.

### [Attack Simulation Training List](https://github.com/HotCakeX/MicrosoftDomains/blob/main/Microsoft%20Domains%20-%20Attack%20Simulation%20Training.txt)

They were gathered from this [source](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/attack-simulation-training-get-started?view=o365-worldwide#simulations) and are valid Microsoft owned domains but kept in a separate list because they are used for training purposes.

<br>

## Automated GitHub Workflow

The [GitHub action](https://github.com/HotCakeX/MicrosoftDomains/actions/workflows/Duplicate%20and%20empty%20lines%20removal.yml) runs every time there is a push in this repository, it makes sure:

* There are no empty lines in the lists
* There are no entries in the lists that start with `xn--`
* The lists have no duplicate entires
* The `Microsoft Domains - EASM.txt` does not include any domain that already exists in `Microsoft Domains.txt`
* There are no entries with non-alphanumeric characters

<br>

## Some of the Sources

* https://learn.microsoft.com/en-us/power-platform/admin/online-requirements
* https://learn.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges
* https://learn.microsoft.com/en-us/azure/security/fundamentals/azure-domains
* https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints

<br>

## Contributing

Please feel free to contribute to this repository by creating a pull request for PowerShell scripts or domains.

### Note

If you're adding a domain, make sure the Whois information is not private for it and explicitly states that it's owned by Microsoft, you can also view the assigned name servers to the domain to make sure it's owned by Microsoft. For example if they point to the Azure name servers.

<p align="center">
<img src="https://raw.githubusercontent.com/HotCakeX/.github/main/Pictures/Gifs/thankyou.gif" alt="Thank You Gif">
</p>
