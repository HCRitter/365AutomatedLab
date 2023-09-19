<#
.SYNOPSIS
Creates new SharePoint Online sites based on the data from an Excel file.

.DESCRIPTION
The `New-365CTSharePointSite` function connects to SharePoint Online(PnP) using the provided admin URL and imports site data from the specified Excel file. It then attempts to create each site based on the data.

.PARAMETER FilePath
The path to the Excel file containing the SharePoint site data. The file must exist and have an .xlsx extension.

.PARAMETER AdminUrl
The SharePoint Online admin URL.

.PARAMETER Domain
The domain information required for the SharePoint site creation.

.EXAMPLE
New-CT365SharePointSite -FilePath "C:\path\to\file.xlsx" -AdminUrl "https://admin.sharepoint.com" -Domain "contoso.com"

This example creates SharePoint sites using the data from the "file.xlsx" and connects to SharePoint Online using the provided admin URL.

.NOTES
Make sure you have the necessary modules installed: ImportExcel, PnP.PowerShell, and PSFramework.

.LINK
https://docs.microsoft.com/powershell/module/sharepoint-pnp/new-pnpsite
#>
function New-CT365SharePointSite {
    [CmdletBinding()]
    param (
        # Validate the Excel file path.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            switch ($psitem){
                {-not([System.IO.File]::Exists($psitem))}{
                    throw "Invalid file path: '$PSitem'."
                }
                {-not(([System.IO.Path]::GetExtension($psitem)) -match "(.xlsx)")}{
                    "Invalid file format: '$PSitem'. Use .xlsx"
                }
                Default{
                    $true
                }
            }
        })]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if ($_ -match '^[a-zA-Z0-9]+\.sharepoint\.[a-zA-Z0-9]+$') {
                $true
            } else {
                throw "The URL $_ does not match the required format."
            }
        })]
        [string]$AdminUrl,

        # Domain information.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            # Check if the domain fits the pattern
            switch ($psitem) {
                {$psitem -notmatch '^(((?!-))(xn--|_)?[a-z0-9-]{0,61}[a-z0-9]{1,1}\.)*(xn--)?[a-z]{2,}(?:\.[a-z]{2,})+$'}{
                    throw "The provided domain is not in the correct format."
                }
                Default {
                    $true
                }
            }
        })]
        [string]$Domain
    )

    begin {
        # Set default message parameters.
        $PSDefaultParameterValues = @{
            "Write-PSFMessage:Level"    = "OutPut"
            "Write-PSFMessage:Target"   = "Preparation"
        }

        # Import required modules.
        $ModulesToImport = "ImportExcel","PnP.PowerShell","PSFramework"
        Import-Module $ModulesToImport

        try {
            # Connect to SharePoint Online.
            $connectPnPOnlineSplat = @{
                Url = $AdminUrl
                Interactive = $true
                ErrorAction = 'Stop'
            }
            Connect-PnPOnline @connectPnPOnlineSplat
        }
        catch {
            # Log an error and exit if the connection fails.
            Write-PSFMessage -Message "Failed to connect to SharePoint Online" -Level Error 
            return 
        }

        try {
            # Import site data from Excel.
            $SiteData = Import-Excel -Path $FilePath -WorksheetName "Sites"
        }
        catch {
            # Log an error and exit if importing site data fails.
            Write-PSFMessage -Message "Failed to import SharePoint Site data from Excel file." -Level Error 
            return
        }
    }

    process {
        foreach ($site in $siteData) {
            # Set the message target to the site's title.
            $PSDefaultParameterValues["Write-PSFMessage:Target"] = $site.Title

            # Log a message indicating site creation.
            Write-PSFMessage -Message "Creating SharePoint Site: '$($site.Title)'"

            # Initialize parameters for creating a new SharePoint site.
            $newPnPSiteSplat = @{
                Type = $null
                TimeZone = $site.Timezone
                Title = $site.Title
                ErrorAction = "Stop"
            }

            switch -Regex ($site.SiteType) {
                "^TeamSite$" {
                    $newPnPSiteSplat.Type = $PSItem 
                    $newPnPSiteSplat.add("Alias",$site.Alias)
                }
                "^(CommunicationSite|TeamSiteWithoutMicrosoft365Group)$" {
                    $newPnPSiteSplat.Type = $PSItem 
                    $newPnPSiteSplat.add("Url",$site.Url)
                }
                default {
                    # Log an error for unknown site types and skip to the next site.
                    Write-PSFMessage "Unknown site type: $($site.SiteType) for site $($site.Title). Skipping." -Level Error
                    # Continue to the next site in the loop.
                    continue
                }
            }

            try {
                # Attempt to create a new SharePoint site using specified parameters.
                New-PnPSite @newPnPSiteSplat 
                Write-PSFMessage -Message "Created SharePoint Site: '$($site.Title)'"
            }
            catch {
                # Log an error message if site creation fails and continue to the next site.
                Write-PSFMessage -Message "Could not create SharePoint Site: '$($site.Title)' Skipping" -Level Error
                Write-PSFMessage -Message $Psitem.Exception.Message -Level Error
                Continue
            }
        }
    }

    end {
        # Log a message indicating completion of the SharePoint site creation process.
        Write-PSFMessage "SharePoint site creation process completed."
        
        # Disconnect from SharePoint Online.
        Disconnect-PnPOnline
    }
}