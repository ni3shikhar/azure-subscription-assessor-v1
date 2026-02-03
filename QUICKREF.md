# Azure Assessment Toolkit - Quick Reference Card

## 🚀 Run Commands

```powershell
# Network security audit
.\AzureNetworkingAudit.ps1

# Security compliance audit  
.\AzureSecurityAssessment.ps1

# Cost analysis (last 3 months)
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3

# Cost analysis (last 12 months)
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 12

# Import actual costs from Portal export
.\ImportActualCosts.ps1 -CostAssessmentCSV "CostAssessment_DetailedCosts.csv" `
  -PortalCostExportCSV "PortalCosts.csv"
```

---

## 📊 What Each Script Produces

### AzureNetworkingAudit.ps1
- **Findings**: 37 network security controls
- **CSV Columns**: Assessment Date, Level, Category, Name, Severity, Control, Finding, etc.
- **Output**: CSV + Summary report
- **Runtime**: ~2 minutes

### AzureSecurityAssessment.ps1  
- **Findings**: 26+ CIS Benchmark controls
- **CSV Columns**: Assessment Date, Category, Control Number, Title, Status (Pass/Fail), etc.
- **Output**: CSV + Summary report
- **Runtime**: ~5 minutes

### AzureSubscriptionCostAssessment.ps1
- **Resources**: 76+ resources analyzed
- **CSV Columns**: Name, ServiceType, EstimatedCost, ActualCost, Location, ResourceGroup, etc.
- **Costs**: Monthly breakdown with month names
- **Output**: CSV + Summary report
- **Runtime**: ~3 minutes

---

## 🔧 Troubleshooting

### Actual Costs Show $0
```
CAUSE: Missing Billing Reader role
SOLUTION 1: Ask admin to grant "Billing Reader" role (takes 5-10 min)
SOLUTION 2: Use ImportActualCosts.ps1 to merge Portal costs (takes 5 min)
SEE: ACTUAL_COSTS_GUIDE.md for detailed instructions
```

### "Command Not Found"
```
CAUSE: Azure CLI not installed
FIX: Visit https://learn.microsoft.com/cli/azure/install-azure-cli
```

### "Not Authorized"
```
CAUSE: Wrong subscription or insufficient permissions
FIX 1: Check subscription: az account show
FIX 2: Switch subscription: az account set --subscription <name-or-id>
FIX 3: Request Reader role from admin
```

### Scripts Run Slow
```
NORMAL: Scripts take 2-10 minutes depending on resource count
TIP: Consider filtering with -ResourceGroupFilter parameter
```

---

## 📋 Permission Requirements

| Script | Min Role | For Actual Costs |
|--------|----------|------------------|
| Network Audit | Reader | N/A |
| Security Audit | Reader | N/A |
| Cost Audit | Reader | Billing Reader* |
| ImportActualCosts | None | N/A |

*Actual costs require Billing Reader; estimated costs work without it

---

## 📈 Typical Cost Output Example

```
Subscription Level:
  Estimated Monthly: $3,136.50
  Estimated Annual: $37,638.00

By Resource Group:
  rg-prod-web: $850.50/month
  rg-databricks: $401.50/month
  rg-monitoring: $209.60/month
  [others...]

By Service Type:
  Virtual Machines: $146.00/month
  SQL Databases: $327.75/month
  Storage: $219.00/month
  Key Vault: $730.00/month
  [others...]

By Resource:
  [Individual resources with costs, location, tags]
```

---

## 🛠️ Setup Checklist

- ✅ Azure CLI installed (`az --version`)
- ✅ Logged into Azure (`az login`)
- ✅ Correct subscription selected (`az account show`)
- ✅ PowerShell 5.1+ (`$PSVersionTable`)
- ✅ Scripts executable (`Set-ExecutionPolicy RemoteSigned`)

---

## 📁 Output Structure

Each script creates a timestamped directory:
```
AzureNetworkingAudit_20260203_101515/
├── NetworkingAudit_DetailedFindings.csv    (37 findings)
└── NetworkingAudit_Summary.txt

AzureSecurityAssessment_20260203_102030/
├── SecurityAssessment_DetailedFindings.csv  (26 findings)
└── SecurityAssessment_Summary.txt

AzureCostAssessment_20260203_101515/
├── CostAssessment_DetailedCosts.csv        (76 resources)
└── CostAssessment_Summary.txt
```

---

## 🎯 Daily Workflow

1. **Week 1**: Run all three scripts to establish baseline
2. **Week 2**: Review findings with security/ops teams
3. **Month 1**: Create remediation plan for top findings
4. **Month 2+**: Re-run scripts monthly to track progress

---

## 💡 Tips & Tricks

### Export to Excel
```powershell
# Open CSV in Excel and create pivot tables
Start-Process "CostAssessment_DetailedCosts.csv"
```

### Archive Results for Trend Analysis
```powershell
$date = Get-Date -Format "yyyyMMdd"
Copy-Item "CostAssessment_DetailedCosts.csv" "Archive_$date.csv"
```

### Filter by Resource Group
```powershell
# Only audit specific resource groups
.\AzureNetworkingAudit.ps1 -ResourceGroupFilter "rg-prod-*"
```

### Schedule Weekly Assessments
```powershell
# Create scheduled task (as administrator)
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 2AM
$action = New-ScheduledTaskAction -Execute PowerShell -Argument `
  "-NoProfile -File 'C:\path\AzureSubscriptionCostAssessment.ps1'"
Register-ScheduledTask -TaskName "AzureAssessment" -Trigger $trigger -Action $action
```

---

## 📞 Resources

- **Documentation**: USAGE_GUIDE.md
- **Cost Issues**: ACTUAL_COSTS_GUIDE.md  
- **Toolkit Summary**: TOOLKIT_SUMMARY.md
- **Azure Docs**: https://learn.microsoft.com/azure/
- **Azure CLI**: https://learn.microsoft.com/cli/azure/
- **CIS Benchmark**: https://www.cisecurity.org/benchmark/azure

---

## ✅ Quick Status Check

```powershell
# Verify everything is set up
Write-Host "PowerShell Version:" $PSVersionTable.PSVersion
Write-Host "Azure CLI:" (az --version | Select-Object -First 1)
Write-Host "Current Subscription:" (az account show --query name -o tsv)
Write-Host "Your Role:" (az role assignment list --assignee (az account show --query user.name -o tsv) --query [0].roleDefinitionName -o tsv)
```

---

**Version**: 1.0 | **Date**: February 2026 | **Status**: ✅ Ready to Use
