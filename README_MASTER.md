# Azure Assessment Toolkit - Master README

## 🎯 Purpose

Complete governance toolkit for Azure subscriptions with three assessment scripts:
- **Network Security Audit** - 37 network controls
- **Security Compliance Audit** - 26 CIS Benchmark controls  
- **Cost Analysis** - Multi-level cost breakdown

## ⚡ Quick Start (2 Minutes)

```powershell
# 1. Navigate to scripts directory
cd "c:\git_2026\azure-subscription-assessor-v1\azure-subscription-assessor-v1\"

# 2. Make sure you're logged in
az login
az account show  # Verify correct subscription

# 3. Run a script
.\AzureNetworkingAudit.ps1           # ~2 minutes
# OR
.\AzureSecurityAssessment.ps1         # ~5 minutes
# OR
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3  # ~3 minutes

# 4. Check outputs
ls -Filter "Azure*" -Directory | Select-Object -Last 1
```

## 📚 Documentation

Start with one of these based on your need:

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[QUICKREF.md](QUICKREF.md)** | Commands, outputs, troubleshooting cheat sheet | 5 min |
| **[TOOLKIT_SUMMARY.md](TOOLKIT_SUMMARY.md)** | Overview, what works, next steps | 5 min |
| **[USAGE_GUIDE.md](USAGE_GUIDE.md)** | Complete guide with detailed examples | 15 min |
| **[ACTUAL_COSTS_GUIDE.md](ACTUAL_COSTS_GUIDE.md)** | Solve "actual costs = $0" issue | 10 min |

## 🛠️ Assessment Scripts

### 1. Network Security Audit
```powershell
.\AzureNetworkingAudit.ps1 [-ResourceGroupFilter "rg-*"]
```
**Checks**: 37 network security controls including:
- Network access policies
- DDoS protection
- Encryption in transit
- Logging and monitoring
- Network segmentation

**Output**: CSV with findings + summary report

**Example Findings**:
- ❌ VNet without NSG
- ❌ Public IP without DDoS
- ❌ RDP open to 0.0.0.0/0
- ✅ Encryption enabled (PASS)

### 2. Security Compliance Assessment  
```powershell
.\AzureSecurityAssessment.ps1 [-SubscriptionName "name"]
```
**Checks**: 147+ CIS Azure Foundations Benchmark controls including:
- Identity and Access Management (IAM)
- Data protection and encryption
- Logging and monitoring
- Key Vault configuration
- Storage security
- SQL security

**Output**: CSV with compliance status + summary report

**Example Findings**:
- ❌ MFA not enabled
- ❌ Public storage access
- ❌ Key Vault without soft delete
- ✅ Encryption at rest (PASS)

### 3. Cost Assessment
```powershell
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3
```
**Analyzes**: 76+ resources across subscription, RGs, service types

**Features**:
- Estimated monthly/annual costs
- Monthly breakdown with readable month names
- Per-resource cost attribution
- Service type aggregation
- Cost trend analysis

**Output**: CSV with costs + summary report

**Example Output**:
```
Subscription Total: $3,136.50/month ($37,638/year)

By Service Type:
  Virtual Machines: $146/month
  SQL Databases: $327.75/month
  Storage: $219/month
  Key Vault: $730/month
  [...]

By Resource:
  myvm-prod-01: $36.50/month (East US)
  mydb-prod-01: $109.50/month (East US)
  [...]
```

## 🔧 Helper Scripts

### Import Actual Costs from Portal
```powershell
.\ImportActualCosts.ps1 `
  -CostAssessmentCSV "CostAssessment_DetailedCosts.csv" `
  -PortalCostExportCSV "PortalCosts.csv"
```

Merges actual costs from Azure Portal export into cost assessment CSV.

## 🎯 Common Scenarios

### Scenario 1: "I need to audit network security"
```powershell
.\AzureNetworkingAudit.ps1
# Results in: 37 findings with severity levels (Critical/High/Medium/Low)
# Action: Review findings, create remediation plan
```

### Scenario 2: "Check CIS Benchmark compliance"
```powershell
.\AzureSecurityAssessment.ps1  
# Results in: 26+ compliance failures
# Action: Fix highest-risk items first
```

### Scenario 3: "Understand resource costs"
```powershell
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 12
# Results in: Cost breakdown by RG, service type, resource
# Action: Identify expensive resources, optimize
```

### Scenario 4: "Actual costs showing $0"
```powershell
# READ: ACTUAL_COSTS_GUIDE.md
# SOLUTION 1: Request Billing Reader role (5 min activation)
# SOLUTION 2: Use ImportActualCosts.ps1 with Portal data (5 min)
```

## 🚨 Common Issues & Solutions

### "Scripts are slow"
- **Normal**: Takes 2-10 minutes depending on subscription size
- **Optimization**: Use `-ResourceGroupFilter` to filter specific RGs
- **Patience**: Large subscriptions (100+ resources) may take longer

### "Scripts show permission errors"
```powershell
# Verify subscription
az account show

# Check your roles
az role assignment list --assignee (az account show --query user.name -o tsv)

# Switch subscription if needed
az account set --subscription "name-or-id"

# Request role from admin if needed:
# - Network/Security audits need: Reader
# - Cost audits (actual costs) need: Billing Reader
```

### "Actual costs = $0 but I see costs in Portal"
1. **Check**: Do you have Billing Reader role?
   - Portal → Subscriptions → Access control (IAM) → Role assignments
2. **If No**: Ask admin to grant "Billing Reader" role (wait 5-10 min)
3. **If Yes**: Re-run script, should work now
4. **Still No**: Use ImportActualCosts.ps1 instead
5. **Need Help**: See ACTUAL_COSTS_GUIDE.md

### "Azure CLI not found"
```powershell
# Check if installed
az --version

# If not, install from:
# https://learn.microsoft.com/cli/azure/install-azure-cli
```

## 📋 Permission Requirements

```
Network Audit:           Reader (minimum)
Security Audit:          Reader (minimum)  
Cost Audit (estimated):  Reader (minimum)
Cost Audit (actual):     Billing Reader (optional, for real costs)
ImportActualCosts:       None (local PowerShell script)
```

## 📊 Output Files

Each script creates a timestamped directory with:
- **`*_DetailedFindings.csv`** or **`*_DetailedCosts.csv`** - Machine-readable results
- **`*_Summary.txt`** - Human-readable summary and recommendations

Examples:
```
AzureNetworkingAudit_20260203_101515/
├── NetworkingAudit_DetailedFindings.csv
└── NetworkingAudit_Summary.txt

AzureSecurityAssessment_20260203_102030/
├── SecurityAssessment_DetailedFindings.csv
└── SecurityAssessment_Summary.txt

AzureCostAssessment_20260203_101515/
├── CostAssessment_DetailedCosts.csv
└── CostAssessment_Summary.txt
```

## 🎯 Usage Patterns

### One-Time Assessment
```powershell
# Run all three scripts once to establish baseline
.\AzureNetworkingAudit.ps1
.\AzureSecurityAssessment.ps1
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3
```

### Monthly Trend Analysis
```powershell
# Archive previous results
$date = Get-Date -Format "yyyyMMdd"
Copy-Item "CostAssessment_DetailedCosts.csv" "Archive_$date.csv"

# Re-run assessment
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3

# Compare with previous month to identify cost changes
```

### Continuous Monitoring (Advanced)
```powershell
# Create Windows scheduled task to run weekly
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 2AM
$action = New-ScheduledTaskAction -Execute PowerShell `
  -Argument "-File C:\path\AzureSubscriptionCostAssessment.ps1"
Register-ScheduledTask -TaskName AzureAssessment -Trigger $trigger -Action $action
```

## 🔗 Integration Examples

### Export to Excel
```powershell
# Open CSV in Excel
Start-Process "CostAssessment_DetailedCosts.csv"

# In Excel:
# 1. Select data
# 2. Insert → Pivot Table
# 3. Rows: ServiceType, Columns: Level, Values: EstimatedCost
# 4. Get cost summary visualization
```

### Import to Power BI
1. Power BI Desktop → Get Data → Text/CSV
2. Select `CostAssessment_DetailedCosts.csv`
3. Create visualizations:
   - Costs by Service Type (bar chart)
   - Costs by Resource Group (pie chart)
   - Monthly Trend (line chart)
   - Resource Details (table)

### SQL Server Import
```sql
-- Create table
CREATE TABLE AzureCosts (
    ResourceId NVARCHAR(MAX),
    ServiceType NVARCHAR(100),
    EstimatedCost MONEY,
    ActualCost MONEY,
    Location NVARCHAR(100)
);

-- Import CSV
BULK INSERT AzureCosts FROM 'CostAssessment_DetailedCosts.csv'
WITH (FIRSTROW = 2, FORMAT = 'CSV');
```

## 📈 Recommended Workflow

```
Week 1: Run baselines
├─ Network audit
├─ Security audit  
├─ Cost assessment
└─ Archive results

Week 2: Analysis
├─ Review findings with team
├─ Prioritize by severity/impact
└─ Create remediation plan

Week 3-4: Remediation
├─ Implement fixes
├─ Re-run audits to verify
└─ Update documentation

Month 2+: Continuous
├─ Monthly re-assessments
├─ Track progress
├─ Optimize costs
└─ Monitor compliance
```

## 💡 Best Practices

✅ **Run regularly** - Monthly recommended for tracking trends  
✅ **Archive results** - Keep historical data for comparison  
✅ **Involve stakeholders** - Share findings with security/ops/finance teams  
✅ **Act on findings** - Don't just generate reports  
✅ **Combine tools** - Use with Azure Advisor, Security Center  
✅ **Automate** - Schedule monthly assessments  
✅ **Document changes** - Note fixes between assessment runs  

## 🆘 Troubleshooting Quick Links

- **Can't run scripts?** → Check prerequisites section
- **Permission errors?** → Check Permission Requirements section
- **Actual costs = $0?** → See ACTUAL_COSTS_GUIDE.md
- **Scripts are slow?** → This is normal; use filters to speed up
- **Need more help?** → See USAGE_GUIDE.md

## 📞 Support Resources

- **Microsoft Azure Docs**: https://learn.microsoft.com/azure/
- **Azure CLI Reference**: https://learn.microsoft.com/cli/azure/
- **CIS Benchmarks**: https://www.cisecurity.org/benchmark/azure
- **Cost Management**: https://learn.microsoft.com/azure/cost-management-billing/
- **Security Center**: https://learn.microsoft.com/azure/defender-for-cloud/

## 📄 File Guide

| File | Purpose |
|------|---------|
| `AzureNetworkingAudit.ps1` | Network security audit script |
| `AzureSecurityAssessment.ps1` | CIS compliance audit script |
| `AzureSubscriptionCostAssessment.ps1` | Cost analysis script |
| `ImportActualCosts.ps1` | Helper to import Portal costs |
| `QUICKREF.md` | Quick reference card (commands, outputs, troubleshooting) |
| `TOOLKIT_SUMMARY.md` | Summary of what works and next steps |
| `USAGE_GUIDE.md` | Complete documentation |
| `ACTUAL_COSTS_GUIDE.md` | Detailed guide to solve actual costs issues |
| `README.md` | This file |
| `NETWORKINGRULES.md` | Network audit control definitions |
| `SECURITYRULES.md` | Security audit control definitions |

## ✅ Status

| Component | Status | Notes |
|-----------|--------|-------|
| Network Audit | ✅ Production Ready | 37 controls, fully functional |
| Security Audit | ✅ Production Ready | 26+ findings, fully functional |
| Cost Assessment | ✅ Production Ready | Estimated costs working; actual costs require Billing Reader role |
| Helper Scripts | ✅ Ready | ImportActualCosts.ps1 available |
| Documentation | ✅ Complete | Comprehensive guides provided |

## 🎓 Getting Started

**New Users**: Start here
1. Read [QUICKREF.md](QUICKREF.md) (5 min)
2. Run one script (e.g., `.\AzureNetworkingAudit.ps1`)
3. Review the output CSV and summary report
4. Read [USAGE_GUIDE.md](USAGE_GUIDE.md) for deeper understanding

**Experienced Users**: Jump straight to
- Run all three scripts
- Read [TOOLKIT_SUMMARY.md](TOOLKIT_SUMMARY.md) for status
- Address actual costs issue per [ACTUAL_COSTS_GUIDE.md](ACTUAL_COSTS_GUIDE.md)
- Integrate with your governance workflow

---

## 📝 Version Information

**Version**: 1.0  
**Release Date**: February 2026  
**Last Updated**: February 3, 2026  
**PowerShell Version**: 5.1+ required  
**Azure CLI Version**: 2.x required  

---

## 🚀 Next Steps

1. **Immediate**: Run scripts to assess current state
2. **Short-term** (Week 1): Review findings, prioritize issues
3. **Medium-term** (Month 1): Implement fixes, measure progress
4. **Long-term** (Ongoing): Monthly assessments, continuous improvement

---

**Questions?** Check the appropriate guide:
- Quick answers → [QUICKREF.md](QUICKREF.md)
- "What's working" → [TOOLKIT_SUMMARY.md](TOOLKIT_SUMMARY.md)
- Detailed guidance → [USAGE_GUIDE.md](USAGE_GUIDE.md)
- Actual costs issues → [ACTUAL_COSTS_GUIDE.md](ACTUAL_COSTS_GUIDE.md)

---

**Happy assessing! 🎯**
