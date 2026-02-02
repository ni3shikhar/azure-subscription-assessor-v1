# Quick Start Guide - Azure Networking Assessment

## 5-Minute Setup

### Step 1: Install Azure CLI
```powershell
# Download and install (one-time setup)
winget install Microsoft.AzureCLI

# Verify installation
az --version
```

### Step 2: Login to Azure
```powershell
# Interactive login
az login

# If using a corporate account with MFA
az login --use-device-code
```

### Step 3: Run the Assessment
```powershell
# Navigate to script directory
cd "c:\git_2026\New folder"

# Run with default settings
.\AzureNetworkingAudit.ps1

# Or specify subscription
.\AzureNetworkingAudit.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Step 4: View Results
```powershell
# View CSV in PowerShell table format
Import-Csv .\AzureNetworkingAudit_*.csv | Format-Table -AutoSize

# Or open in Notepad/Excel
.\AzureNetworkingAudit_*.csv
```

## Common Commands

### Get Your Subscription ID
```powershell
az account list --output table
```

### View Only Critical Findings
```powershell
Import-Csv .\AzureNetworkingAudit_*.csv | Where-Object {$_.Criticality -eq 'Critical'} | Format-Table
```

### Count Findings by Category
```powershell
Import-Csv .\AzureNetworkingAudit_*.csv | Group-Object Category -NoElement
```

### Export to Excel
```powershell
# Install-Module ImportExcel (first time only)
Import-Csv .\AzureNetworkingAudit_*.csv | Export-Excel -Path .\Report.xlsx -AutoSize
```

## Understanding Your Results

| Criticality | What It Means | Example |
|------------|--------------|---------|
| 🔴 **Critical** | Fix immediately | SSH open to entire internet |
| 🟠 **High** | Fix soon | No DDoS protection enabled |
| 🟡 **Medium** | Plan remediation | No Bastion host configured |
| 🟢 **Low** | Best practice | Custom route tables not used |
| ℹ️ **Info** | Informational | All checks passed |

## Top 5 Common Issues Found

1. **NSG rules allow RDP/SSH from internet** → Restrict source IPs
2. **No flow logs enabled** → Enable Network Watcher flow logs
3. **Public IPs using Basic SKU** → Migrate to Standard SKU
4. **No DDoS Protection** → Enable DDoS Protection Standard
5. **No Azure Firewall** → Deploy centralized firewall

## Quick Remediation Examples

### Close SSH/RDP to Internet
```powershell
# Replace values with your details
$rgName = "myResourceGroup"
$nsgName = "myNSG"

# Close SSH (22)
az network nsg rule update --resource-group $rgName --nsg-name $nsgName --name "AllowSSH" --source-address-prefixes "10.0.0.0/8"

# Close RDP (3389)
az network nsg rule update --resource-group $rgName --nsg-name $nsgName --name "AllowRDP" --source-address-prefixes "10.0.0.0/8"
```

### Enable Flow Logs
```powershell
$rgName = "myResourceGroup"
$nsgName = "myNSG"
$storageName = "mystorageaccount"

az network watcher flow-log create \
  --resource-group $rgName \
  --enabled true \
  --nsg $nsgName \
  --storage-account $storageName
```

### Enable DDoS Protection
```powershell
$rgName = "myResourceGroup"
$vnetName = "myVNet"

# Create DDoS Plan
az network ddos-protection create --resource-group $rgName --name "DDoSPlan"

# Apply to VNet
az network vnet update --resource-group $rgName --name $vnetName --ddos-protection-plan "DDoSPlan"
```

## Scheduling Regular Checks

### Run Weekly Check
```powershell
# Create scheduled task in Task Scheduler
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -File 'c:\git_2026\New folder\AzureNetworkingAudit.ps1'"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 02:00AM
Register-ScheduledTask -TaskName "Azure Networking Audit" -Action $action -Trigger $trigger -RunLevel Highest
```

## Troubleshooting

### "az: command not found"
→ Azure CLI not installed. Run `winget install Microsoft.AzureCLI`

### "UnauthorizedException: The user..."
→ Not logged in. Run `az login`

### "The subscription does not have valid agreements"
→ Login issue. Try `az login --use-device-code`

### Script runs but finds no resources
→ Check subscription: `az account show`
→ Check permissions: Need Reader role or higher

## Next Steps

1. **Schedule regular runs** - Weekly or monthly
2. **Track improvements** - Save reports and compare over time
3. **Remediate findings** - Use recommendations in the CSV
4. **Document changes** - Keep audit trail of network changes
5. **Alert on new findings** - Compare reports to detect new issues

## Getting Help

- **Azure CLI help**: `az network --help`
- **Check status**: `az account show` and `az account list`
- **List all resources**: `az resource list --output table`

---

**Pro Tip**: Save the CSV reports in a shared folder to track compliance over time and create trends!
