This script checks all of your Entra ID Microsoft 365 tenant for Shadow IT/Unapproved third party Teams Apps, which can easily happen since Microsoft has decoupled Teams Apps from Entra ID apps, to where users may be allowed to install any third party app they want.

We used this to successfully clear out all installed Third Party apps after blocking the feature of letting users install them at:

https://admin.teams.microsoft.com/policies/manage-apps -> (Settings) Org-wide App Settings:

Third-party apps (OFF)
Custom apps - Let Users intall/interact (OFF)
