# Azure Assessment Scripts - Complete Guide

Complete Azure governance toolkit with three complementary assessment scripts for network security, compliance, and cost analysis.

## 📋 Overview

This toolkit provides three PowerShell scripts that generate comprehensive Azure assessments:

| Script | Purpose | Framework | Findings |
|--------|---------|-----------|----------|
| **AzureNetworkingAudit.ps1** | Network security configuration audit | Custom security model | 37+ findings |
| **AzureSecurityAssessment.ps1** | Security compliance assessment | CIS Azure Foundations Benchmark v1.5.0 | 26+ findings |
| **AzureSubscriptionCostAssessment.ps1** | Multi-level cost analysis | Azure resource enumeration | 76+ resources analyzed |

## 🚀 Quick Start

### Prerequisites
- Windows PowerShell 5.1 or higher
- Azure CLI 2.x installed and configured
- Azure account with appropriate permissions:
  - **For network/security audits**: Reader role on subscription
  - **For actual costs**: Billing Reader or Owner role (optional - estimated costs work without it)

### Installation

1. **Clone/Download the scripts**:
   ```powershell
   git clone <repo-url>
   cd azure-assessment-scripts
   ```

2. **Ensure Azure CLI is connected**:
   ```powershell
   az login
   az account set --subscription "subscription-name-or-id"
   ```

3. **Run an assessment**:
   ```powershell
   # Network audit (quick, ~2 min)
   .\AzureNetworkingAudit.ps1
   
   # Security assessment (medium, ~5 min)
   .\AzureSecurityAssessment.ps1
   
   # Cost assessment (medium, ~3 min)
   .\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3
   ```

## 📊 Output

All scripts generate two output files in a timestamped directory:

### CSV File (Machine-readable)
- Contains all findings/resources with detailed metadata
- Ready for importing into Excel, databases, or BI tools
- Columns vary by script (see below)

### Summary Report (Human-readable)
- Text file with formatted findings
- Risk summary and aggregations
- Recommendations and next steps

---

## 1️⃣ Network Audit Script

### Purpose
Comprehensive audit of Azure network configurations against 12 security control categories.

### Usage
```powershell
.\AzureNetworkingAudit.ps1 [-ResourceGroupFilter "rg-*"]
```

### Parameters
- `ResourceGroupFilter`: (Optional) Filter to specific resource groups. Example: `"rg-prod-*"` or `"prod-*"`

### Output Structure
**CSV Columns** (Network Audit):
- AssessmentDate, Level, Category, Name, Severity
- Control, Finding, CurrentValue, RecommendedValue
- ResourceId, ResourceGroup, AffectedResource, Impact
- RemediationSteps, CostOfRemediation, ImplementationComplexity

**Findings Example**:
- Virtual Network without NSG
- Public IP Address without DDoS protection
- Unrestricted RDP access (0.0.0.0/0)
- Diagnostic logging not enabled
- VPN Gateway with weak protocols

### Key Metrics
- Severity levels: Critical (2) | High (15) | Medium (8) | Low (12) | Info (9)
- Coverage: 37 security controls
- Scope: VNets, NSGs, Subnets, NICs, Public IPs, Firewalls, VPN Gateways, Application Gateways

---

## 2️⃣ Security Assessment Script

### Purpose
Evaluate subscription compliance with CIS Azure Foundations Benchmark v1.5.0.

### Usage
```powershell
.\AzureSecurityAssessment.ps1 [-SubscriptionName "my-subscription"]
```

### Parameters
- `SubscriptionName`: (Optional) Specific subscription to audit. Default: current subscription

### Output Structure
**CSV Columns** (Security Assessment):
- AssessmentDate, Category, ControlNumber, ControlTitle, ServiceArea
- Status (Pass/Fail/N/A), Severity, FindingDetails
- ResourceId, ImplementationGuidance, AuditFrequency

**Findings Example**:
- MFA not enabled for all users
- Storage Accounts with public access
- Key Vault without soft delete
- Diagnostic logging gaps
- Admin roles over-assigned
- SQL databases not encrypted

### CIS Categories Covered
1. Identity and Access Management (IAM)
2. Security Center
3. Storage Accounts
4. Azure SQL Database
5. Logging and Monitoring
6. Networking
7. Key Vault
8. Application Security
9. Data Protection
10. Governance

### Key Metrics
- Frameworks: CIS Azure Foundations Benchmark v1.5.0
- Controls assessed: 147+
- Findings generated: 26+ per typical subscription

---

## 3️⃣ Cost Assessment Script

### Purpose
Multi-level subscription cost analysis with monthly breakdowns and resource-level cost attribution.

### Usage
```powershell
# Analyze last 3 months
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3

# Analyze last 12 months
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 12

# Custom subscription
.\AzureSubscriptionCostAssessment.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -MonthsBack 6
```

### Parameters
- `MonthsBack`: (Optional) Number of months to analyze. Default: 3
- `SubscriptionId`: (Optional) Specific subscription ID. Default: current subscription

### Output Structure
**CSV Columns** (Cost Assessment):
- AssessmentDate, Level, Category, Name, ServiceType
- EstimatedCost, ActualCost, CostVariance, Currency
- TimeFrame, MonthlyCostBreakdown, PercentageOfTotal
- Details, CostTrend, ResourceId, ResourceGroup, Location, Tags

**Analysis Levels**:
1. **Subscription Level**: Total subscription cost
2. **Resource Group Level**: Aggregated by RG
3. **Service Type Level**: By Azure service (VMs, SQL, Storage, etc.)
4. **Resource Type Level**: Individual resources with costs

### Cost Estimation Model
**Hourly Rates** (used when actual costs unavailable):

| Resource Type | Hourly Rate | Monthly (730 hrs) | Annual |
|---|---|---|---|
| Virtual Machine | $0.05 | $36.50 | $438 |
| SQL Database | $0.15 | $109.50 | $1,314 |
| Storage Account | $0.03 | $21.90 | $263 |
| Key Vault | $1.00 | $730.00 | $8,760 |
| App Service | $0.08 | $58.40 | $701 |
| Databricks | $0.55 | $401.50 | $4,818 |
| Network VNet | $0.05 | $36.50 | $438 |
| NSG | $0.04 | $29.20 | $350 |
| Application Insights | $0.10 | $73.00 | $876 |
| Log Analytics | $0.10 | $73.00 | $876 |
| Container Registry | $0.10 | $73.00 | $876 |
| AKS | $0.10 | $73.00 | $876 |

### Actual vs Estimated Costs
The script automatically calculates **estimated costs** for all resources. To add **actual costs** from Azure:

#### Option A: Request RBAC Role (Recommended)
Ask your admin to grant "Billing Reader" or "Cost Management Reader" role:
1. Portal → Subscriptions → Select your subscription
2. Click "Access control (IAM)" → "Add role assignment"
3. Select "Billing Reader"
4. Add your email, click Assign
5. Re-run script (takes effect in 5-10 minutes)

#### Option B: Import from Portal
Use the **ImportActualCosts.ps1** helper script:
```powershell
# Export costs from Portal: Cost Management + Billing > Cost analysis > Export to CSV
.\ImportActualCosts.ps1 `
  -CostAssessmentCSV "CostAssessment_DetailedCosts.csv" `
  -PortalCostExportCSV "PortalCosts.csv"
```

### Example Output
```
Subscription Level Costs:
  Estimated Monthly: $3,136.50
  Estimated Annual: $37,638.00
  Actual Monthly: $3,089.42 (with Billing Reader role)
  Variance: -1.5% (estimated vs actual)

Resource Group: rg-prod-web
  Estimated: $850.50/month
  Resources: 8 (2 VMs, 1 SQL DB, 3 App Services, 2 Storage)

Service Type Breakdown:
  Virtual Machines: $146.00/month (4 resources)
  SQL Databases: $327.75/month (3 resources)
  Storage Accounts: $219.00/month (6 resources)
  ...
```

---

## 🔧 Helper Scripts

### ImportActualCosts.ps1
Merges actual costs from Azure Portal export into cost assessment CSV.

```powershell
# Basic usage
.\ImportActualCosts.ps1 `
  -CostAssessmentCSV "CostAssessment_DetailedCosts.csv" `
  -PortalCostExportCSV "PortalCosts.csv"

# With custom output path
.\ImportActualCosts.ps1 `
  -CostAssessmentCSV "CostAssessment_DetailedCosts.csv" `
  -PortalCostExportCSV "PortalCosts.csv" `
  -OutputCSV "CostAssessment_Final.csv"
```

**Process**:
1. Reads cost assessment CSV
2. Reads Portal export CSV
3. Matches Resource IDs
4. Updates ActualCost column
5. Exports merged CSV

---

## 📈 Typical Workflow

```
┌─────────────────────────────────────────────────────┐
│  1. Initial Discovery                               │
│     .\AzureNetworkingAudit.ps1                      │
│     → Identify network security gaps                │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│  2. Compliance Check                                │
│     .\AzureSecurityAssessment.ps1                   │
│     → Check CIS Benchmark compliance                │
│     → Identify security control failures            │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│  3. Cost Analysis                                   │
│     .\AzureSubscriptionCostAssessment.ps1           │
│     → Understand resource costs                     │
│     → Identify expensive resources                  │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│  4. Add Actual Costs (Optional)                     │
│     .\ImportActualCosts.ps1                         │
│     OR                                              │
│     Request Billing Reader role                     │
│     → Replace estimated with actual costs           │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│  5. Reporting & Remediation                         │
│     • Export CSVs to Excel for analysis             │
│     • Create remediation plan                       │
│     • Track progress with historical CSVs           │
│     • Re-run assessments monthly                    │
└─────────────────────────────────────────────────────┘
```

---

## 📋 Permission Requirements

| Script | Minimum Role | Recommended Role | Notes |
|--------|--------------|------------------|-------|
| AzureNetworkingAudit.ps1 | Reader | Reader | Read-only network resource access |
| AzureSecurityAssessment.ps1 | Reader | Reader | Read-only access to all resources |
| AzureSubscriptionCostAssessment.ps1 | Contributor | Owner | Estimated costs work with Reader; actual costs require Billing Reader |
| ImportActualCosts.ps1 | None | None | Local script, no Azure permissions needed |

---

## 🛠️ Troubleshooting

### "Command not found" errors
```powershell
# Ensure Azure CLI is installed
az --version

# Install if needed
# Visit: https://learn.microsoft.com/cli/azure/install-azure-cli
```

### "Not authorized" or permission errors
```powershell
# Check your current role on subscription
az role assignment list --assignee (az account show --query user.name -o tsv)

# Make sure you're on the right subscription
az account show

# Switch if needed
az account set --subscription "subscription-name-or-id"
```

### Scripts timeout or run slowly
- Network audit: ~2-3 minutes for typical subscriptions
- Security assessment: ~5-10 minutes (depends on resource count)
- Cost assessment: ~3-5 minutes
- Internet connectivity and Azure API latency may affect timing

### Actual costs show as $0
See [ACTUAL_COSTS_GUIDE.md](ACTUAL_COSTS_GUIDE.md) for detailed troubleshooting.

Common causes:
1. **Most Common**: Your account lacks Billing Reader role
2. No billable usage in the specified period
3. Subscription uses Enterprise Agreement (different API)
4. Account lacks permission to access billing APIs

**Solution**: Follow Option A (request role) or Option B (import Portal costs) in ACTUAL_COSTS_GUIDE.md.

---

## 📅 Scheduling Regular Assessments

### Daily Assessment Task (PowerShell)
```powershell
# Create scheduled task for weekly assessments
$scriptPath = "C:\path\to\AzureSubscriptionCostAssessment.ps1"
$taskName = "Azure-CostAssessment-Weekly"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 2AM
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -MonthsBack 3"
Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -RunLevel Highest
```

### Archive Results
```powershell
# Keep historical data for trend analysis
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sourceDir = "AzureCostAssessment_20260203_101515"
Copy-Item "$sourceDir\CostAssessment_DetailedCosts.csv" "Archive\CostAssessment_$timestamp.csv"
```

---

## 📊 Exporting to Excel/BI Tools

All CSV files are compatible with:
- **Excel**: Open directly, create pivot tables for analysis
- **Power BI**: Connect as CSV data source for dashboards
- **Azure Synapse**: Import for advanced analytics
- **Tableau**: Create visualizations
- **SQL Server**: Import for data warehousing

**Example - Excel Pivot Table**:
1. Open CSV in Excel
2. Data → Create PivotTable
3. Rows: ServiceType, Columns: Level, Values: EstimatedCost
4. Get cost summary by service

---

## 🔗 Resources

- [Azure CLI Documentation](https://learn.microsoft.com/cli/azure/)
- [CIS Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)
- [Azure Cost Management Documentation](https://learn.microsoft.com/azure/cost-management-billing/)
- [Azure RBAC Roles Reference](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)
- [Azure REST API Reference](https://learn.microsoft.com/rest/api/azure/)

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 2026 | Initial release - Network, Security, and Cost assessments |

---

## 💡 Best Practices

1. **Run regularly** - Monthly assessments to track trends
2. **Archive results** - Keep historical data for comparison
3. **Combine with other tools** - Use alongside Azure Advisor, Security Center
4. **Review findings** - Don't just generate reports, take action on findings
5. **Track remediation** - Note changes between assessment runs
6. **Involve stakeholders** - Share reports with security, ops, and finance teams
7. **Use actual costs** - Request Billing Reader role for accurate cost data

---

## 🤝 Contributing

To contribute improvements:
1. Test scripts in your environment
2. Report issues with:
   - Azure subscription type (EA, MSDN, Pay-as-you-go, etc.)
   - Resource types affected
   - Error messages and logs
3. Suggest new controls or cost optimization rules

---

## 📄 License

These scripts are provided as-is for Azure governance and assessment purposes.

---

## ❓ FAQ

**Q: Can I run on multiple subscriptions?**  
A: Currently, each script assesses one subscription at a time. Run scripts in a loop for multiple subscriptions.

**Q: Why are actual costs showing as $0?**  
A: Your account likely lacks Billing Reader role. See ACTUAL_COSTS_GUIDE.md for solutions.

**Q: How long do scripts take to run?**  
A: 2-10 minutes depending on subscription size and resource count.

**Q: Can I modify the cost estimation rates?**  
A: Yes! Edit the hourly rates in `Get-EstimatedMonthlyCost` function. See script comments for details.

**Q: Do these scripts modify any resources?**  
A: No! All scripts are read-only and use viewer/reader APIs only.

---

**Last Updated**: February 2026  
**Framework**: PowerShell 5.1, Azure CLI 2.x  
**Status**: ✅ Production Ready
