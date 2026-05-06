# Microsoft Teams App Auditing & Remediation Pipeline

This document outlines the architectural pipeline for auditing and removing unauthorized third-party Microsoft Teams applications across a tenant. Because the Microsoft Graph API does not natively expose the "Publisher Name" via the `teamsApp` endpoints, a dynamic two-phase telemetry approach is required to shield native Microsoft shell apps from destruction.

## Overview
1. **Phase 1: Verification (Telemetry Baseline):** Enumerate the tenant to find all applications not marked as `organization` (which captures both third-party apps and native Microsoft apps).
2. **Phase 2: Isolation & Prompting:** Use PowerShell grouping to isolate core Microsoft apps based on widespread deployment metrics.
3. **Phase 3: Remediation (Purge):** Feed a specific blacklist into the Graph API to purge only unauthorized shadow-IT installations.

---

## Phase 1: Establish the Telemetry Baseline
First, run the Verification script. This iterates through all Team scopes and User scopes, extracting any application where the `DistributionMethod` is not equal to `organization`.

```powershell
# Extracting the baseline via Microsoft Graph
$InstalledApps = Get-MgTeamInstalledApp -TeamId $Team.Id -ExpandProperty "teamsApp"
foreach ($App in $InstalledApps) {
    if ($App.TeamsApp.DistributionMethod -ne 'organization') {
        # Export to PSCustomObject
    }
}
```
**Output:** The script dumps the global tenant baseline to `C:\temp2\TeamsAppRemediation_Report.csv`.

---

## Phase 2: Dynamic Prompting to Isolate Microsoft Apps
Because the verification output includes critical Microsoft shell apps (like *Word*, *SharePoint*, *Files*, and *Calendar*), executing a blind removal will destroy native Teams UI components. 

To safely identify which apps are native Microsoft apps, query the CSV using `Group-Object` and sort by the installation count. Core Microsoft apps will universally match your exact tenant population count (e.g., if you have 5,000 users/teams, native Microsoft apps will show exactly 5,000 installations).

**Run this prompt in PowerShell to group and inspect the data:**
```powershell
Import-Csv "C:\temp2\TeamsAppRemediation_Report.csv" | Group-Object AppName | Select-Object Count, Name | Sort-Object Count -Descending | Format-Table -AutoSize
```

**Analysis Methodology:**
*   **High-Count Apps (Tenant-wide):** These are native Microsoft apps (e.g., *PowerPoint*, *SharePoint Pages*, *Activity*). You must **shield** these.
*   **Low-Count Apps (Fragmented):** These are unauthorized third-party apps installed by isolated users or teams (e.g., *ThirdPartyApp1*, *ShadowITApp2*). These are your **targets**.
*   **High-Count Anomalies:** If a known third-party app (e.g., *ExampleApp*) has a massive installation count matching the tenant population, it is being enforced by a **Teams App Setup Policy**. Graph API cannot delete these; they must be unpinned in the Teams Admin Center first.

---

## Phase 3: Exclusion Arrays and the Remediation Script
When moving to the Remediation script, it is critical to use **Blacklist** logic (targeting explicit third-party apps) rather than Whitelist logic (targeting everything not explicitly saved) to prevent accidental destruction of unmapped Microsoft components.

### 1. Hardcode the Microsoft Whitelist in the Verification Script
To ensure future verification reports are clean, inject the identified Microsoft apps into an exclusion array within your verification loops:

```powershell
$MicrosoftWhitelist = @(
    "Word", "PowerPoint", "Excel", "SharePoint Pages", "Teams", "Chat", "Calendar", # ...etc
)

# Only log apps that are NOT in the Microsoft Whitelist
if ($App.TeamsApp.DistributionMethod -ne 'organization' -and $App.TeamsApp.DisplayName -notin $MicrosoftWhitelist) {
    # Add to findings
}
```

### 2. Build the Target Blacklist for Remediation
In the `Remove-UnauthorizedTeamsApps.ps1` script, define the explicit list of third-party apps you discovered during Phase 2. 

```powershell
# Explicit Blacklist for Safe Destruction
$TargetBlacklist = @(
    "ThirdPartyApp1",
    "ShadowITApp2",
    "ShadowITApp3",
    "ThirdPartyApp4"
)

# Filter the CSV for targets only
$TargetRemediations = Import-Csv $CsvPath | Where-Object { $_.AppName -in $TargetBlacklist }

# Execute Purge
foreach ($Target in $TargetRemediations) {
    if ($Target.ScopeType -eq "Team") {
        Remove-MgTeamInstalledApp -TeamId $Target.ScopeId -TeamsAppInstallationId $Target.AppInstallationId
    }
}
```

> [!WARNING]
> If a `DELETE` request fails with a `[BadGateway] : Failed to execute backend request` error, the targeted app is likely pinned via a global Setup Policy in the Teams Admin Center. Remove the app from the Admin Center policy before attempting API deletion.
