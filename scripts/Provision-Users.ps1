# ============================================================
# Antiseptic Security - Bulk User Provisioning Script
# Purpose: Creates AD user accounts from CSV and assigns groups
# Author: Jacob Sprague
# Date: 2026-03-12
# ============================================================

# --- CONFIGURATION ---
# Path to the CSV file containing employee data
$CSVPath = "Z:\employees.csv"

# Default password for all new accounts (users forced to change at first logon)
$DefaultPassword = ConvertTo-SecureString "Antiseptic2026!" -AsPlainText -Force

# Domain suffix for User Principal Name (UPN) - this is the email-style login
$DomainSuffix = "@antisepticsec.local"

# Base OU path where department OUs live
$BasePath = "OU=Antiseptic Security,DC=antisepticsec,DC=local"

# --- IMPORT CSV ---
$Employees = Import-Csv -Path $CSVPath
Write-Host "Found $($Employees.Count) employees to provision." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- COUNTERS ---
$Created = 0
$Failed = 0
$Skipped = 0

# --- PROCESS EACH EMPLOYEE ---
foreach ($Employee in $Employees) {

    $FirstName  = $Employee.FirstName
    $LastName   = $Employee.LastName
    $Username   = $Employee.Username
    $Department = $Employee.Department
    $OU         = $Employee.OU
    $Title      = $Employee.Title
    $Groups     = $Employee.Groups -split ","

    # Build the OU path based on department
    # SOC sub-OUs nest one level deeper
    if ($OU -like "SOC-*") {
        $UserPath = "OU=$OU,OU=SOC,$BasePath"
    } else {
        $UserPath = "OU=$OU,$BasePath"
    }

    # Build the User Principal Name (email-style login)
    $UPN = "$Username$DomainSuffix"

    # Build the display name
    $DisplayName = "$FirstName $LastName"

    # --- CREATE THE USER ---
    try {
        # Check if user already exists
        $Existing = Get-ADUser -Filter {SamAccountName -eq $Username} -ErrorAction SilentlyContinue

        if ($Existing) {
            Write-Host "[SKIP] $Username already exists." -ForegroundColor Yellow
            $Skipped++
            continue
        }

        New-ADUser `
            -SamAccountName $Username `
            -UserPrincipalName $UPN `
            -Name $DisplayName `
            -GivenName $FirstName `
            -Surname $LastName `
            -DisplayName $DisplayName `
            -Title $Title `
            -Department $Department `
            -Path $UserPath `
            -AccountPassword $DefaultPassword `
            -ChangePasswordAtLogon $true `
            -Enabled $true

        Write-Host "[CREATED] $DisplayName ($Username) -> $UserPath" -ForegroundColor Green

        # --- ASSIGN GROUPS ---
        foreach ($Group in $Groups) {
            $Group = $Group.Trim()
            try {
                Add-ADGroupMember -Identity $Group -Members $Username
                Write-Host "   [GROUP] Added to $Group" -ForegroundColor DarkGreen
            }
            catch {
                Write-Host "   [ERROR] Failed to add to group $Group - $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        $Created++
    }
    catch {
        Write-Host "[FAILED] $Username - $($_.Exception.Message)" -ForegroundColor Red
        $Failed++
    }
}

# --- SUMMARY ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Provisioning Complete" -ForegroundColor Cyan
Write-Host "Created: $Created" -ForegroundColor Green
Write-Host "Skipped: $Skipped" -ForegroundColor Yellow
Write-Host "Failed:  $Failed" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
