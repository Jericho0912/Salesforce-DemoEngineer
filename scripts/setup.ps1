<#
    NTO Demo — one-command setup (Windows / PowerShell)
    Deploys all metadata, assigns the permission set, and loads seed data.
    Usage:  .\scripts\setup.ps1 [-OrgAlias Demo-Org]
#>
param(
    [string]$OrgAlias = "Demo-Org"
)

$ErrorActionPreference = "Stop"

Write-Host "==> NTO Demo setup against org '$OrgAlias'" -ForegroundColor Cyan

Write-Host "`n[1/3] Deploying metadata..." -ForegroundColor Yellow
sf project deploy start -d force-app -o $OrgAlias
if ($LASTEXITCODE -ne 0) { throw "Metadata deploy failed." }

Write-Host "`n[2/3] Assigning permission set NTO_Demo_Access..." -ForegroundColor Yellow
sf org assign permset -n NTO_Demo_Access -o $OrgAlias
# Non-fatal: the permset may already be assigned.

Write-Host "`n[3/3] Loading seed data..." -ForegroundColor Yellow
sf apex run -f scripts/apex/seed.apex -o $OrgAlias
if ($LASTEXITCODE -ne 0) { throw "Seed data load failed." }

Write-Host "`n==> Automated setup complete." -ForegroundColor Green
Write-Host @"

NEXT (one-time manual steps — see README for details):
  1. Activate Lightning pages:
       - Contact -> 'Contact Customer 360'  (org default or app default)
       - Case    -> 'Case Workspace 360'    (assign in 'NTO Service Console' app)
  2. Agentforce: build the agent in Agent Builder and attach the
     'Get NTO Order Status' action and 'NTO Create Return' flow (README > Agentforce Setup).
  3. Experience Cloud: enable Digital Experiences, create the LWR site,
     add the 'My Account (Customer Portal)' component (README > Experience Cloud Setup).
"@ -ForegroundColor Gray
