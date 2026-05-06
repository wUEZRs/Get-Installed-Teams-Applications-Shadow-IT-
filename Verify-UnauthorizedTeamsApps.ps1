# Verification Script: Locate installations of all "store" and "sideloaded" Teams apps
# Note: Graph API does not natively expose Publisher Name (e.g., "Microsoft Corporation").
# Therefore, this script extracts ALL apps not built by your organization,
# which includes both Third-Party apps and Microsoft First-Party apps.

$ExportPath = "C:\temp2\TeamsAppRemediation_Report.csv"

# Ensure the temp directory exists
$TempDir = Split-Path $ExportPath -Parent
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

Write-Host "Connecting to Microsoft Graph..."
# Connect to Graph with the required scopes for enumeration and subsequent removal
Connect-MgGraph -Scopes "AppCatalog.Read.All", "Team.ReadBasic.All", "User.Read.All", "Group.Read.All", "Directory.Read.All"

$Findings = @()

# Comprehensive list of native Microsoft/1st-party apps to exclude from the report
$MicrosoftWhitelist = @(
    "Share to Teams", "Speaker coach", "Inspection", "Bulletins", "SharePoint", 
    "Share conversation", "FileBrowser", "Updates", "Workflows", "Approvals", 
    "Channel calendar", "Engage", "Power Apps", "Shifts", "Polls", "Azure DevOps", 
    "Dynamics 365", "Advisor for Teams", "Incoming Webhook (to be retired)", "Word", 
    "PowerPoint", "Visio", "Excel", "SharePoint Pages", "Milestones", 
    "Meeting Sensitivity Alert", "Meeting attendance report", "Meet", "Activity", 
    "Loop notifications", "Loop", "Lists", "Tags", "Recommendations", "OneDrive", 
    "OneNote", "OneNote (Legacy)", "Organization", "Outgoing Webhook", "PDF", 
    "Search", "Planner", "Saved", "Power Automate Actions", "Power BI", 
    "Power BI (Legacy)", "Praise", "Room Remote", "Teams", "Issue reporting", 
    "Teams Immersive", "Bookable desks ", "Broadcast QnA", "Calendar", "Calling", 
    "Camera", "Channel Pages", "Teams and Channels", "Clipchamp", "Wiki", 
    "Document Library", "Chat", "Website", "Whiteboard", "Forms for Microsoft Teams", 
    "Q&A", "Employee ideas"
)

# 1. Enumerate Team Scopes
Write-Host "Enumerating Teams..."
$AllTeams = Get-MgTeam -All
if (-not $AllTeams) {
    Write-Host "WARNING: 0 Teams found. Ensure you have Directory.Read.All / Group.Read.All consented." -ForegroundColor Yellow
}
else {
    $TeamCount = $AllTeams.Count
    Write-Host "Checking $TeamCount Teams for installed apps..."

    $i = 0
    foreach ($Team in $AllTeams) {
        $i++
        Write-Progress -Activity "Checking Teams" -Status "Processing Team $i of $TeamCount" -PercentComplete (($i / $TeamCount) * 100)
        
        # Expand teamsApp to match the properties
        $InstalledApps = Get-MgTeamInstalledApp -TeamId $Team.Id -ExpandProperty "teamsApp" -ErrorAction SilentlyContinue
        
        foreach ($App in $InstalledApps) {
            if ($App.TeamsApp.DistributionMethod -ne 'organization' -and $App.TeamsApp.DisplayName -notin $MicrosoftWhitelist) {
                $Findings += [PSCustomObject]@{
                    ScopeType          = "Team"
                    ScopeName          = $Team.DisplayName
                    ScopeId            = $Team.Id
                    AppInstallationId  = $App.Id
                    AppName            = $App.TeamsApp.DisplayName
                    TeamsAppId         = $App.TeamsApp.Id
                    DistributionMethod = $App.TeamsApp.DistributionMethod
                }
            }
        }
    }
}

# 2. Enumerate User Scopes
Write-Host "Enumerating Users..."
$AllUsers = Get-MgUser -Filter "accountEnabled eq true" -ConsistencyLevel eventual -All
if (-not $AllUsers) {
    Write-Host "WARNING: 0 Users found. Check your User.Read.All permissions." -ForegroundColor Yellow
    $UserCount = 0
}
else {
    $UserCount = $AllUsers.Count
    Write-Host "Checking $UserCount Users for installed apps..."

    $j = 0
    foreach ($User in $AllUsers) {
        $j++
        Write-Progress -Activity "Checking Users" -Status "Processing User $j of $UserCount" -PercentComplete (($j / $UserCount) * 100)
    
        $InstalledApps = Get-MgUserTeamworkInstalledApp -UserId $User.Id -ExpandProperty "teamsApp" -ErrorAction SilentlyContinue
    
        foreach ($App in $InstalledApps) {
            if ($App.TeamsApp.DistributionMethod -ne 'organization' -and $App.TeamsApp.DisplayName -notin $MicrosoftWhitelist) {
                $Findings += [PSCustomObject]@{
                    ScopeType          = "User"
                    ScopeName          = $User.DisplayName
                    ScopeId            = $User.Id
                    AppInstallationId  = $App.Id
                    AppName            = $App.TeamsApp.DisplayName
                    TeamsAppId         = $App.TeamsApp.Id
                    DistributionMethod = $App.TeamsApp.DistributionMethod
                }
            }
        }
    }
}


Write-Progress -Activity "Checking Users" -Completed

if ($Findings.Count -gt 0) {
    Write-Host "Found $($Findings.Count) installations of Store/Sideloaded apps." -ForegroundColor Yellow
    $Findings | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Exported findings to $ExportPath" -ForegroundColor Green
    
    # Rule compliance: For Excel list work, export to C:\temp2\<name>.csv and open it immediately
    Invoke-Item $ExportPath
}
else {
    Write-Host "No installations of Store/Sideloaded apps found." -ForegroundColor Green
}
