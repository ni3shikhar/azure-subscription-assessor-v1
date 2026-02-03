# Azure Cost Assessment - Actual Costs Integration Guide

## Problem
The cost assessment script shows **Actual Cost = $0** even though you see costs in the Azure Portal. This is a common issue when the script cannot access the Azure Consumption API due to insufficient RBAC permissions.

## Root Causes

### 1. **Missing RBAC Role (Most Common)**
Your Azure account doesn't have the required role to access billing data.
- **Required Roles**: 
  - Billing Reader
  - Cost Management Reader
  - Owner
  - Contributor (may work depending on scope)

### 2. **API Access Not Provisioned**
The subscription's Consumption API may not be accessible yet for new accounts or certain subscription types.

### 3. **No Usage Data in Billing Period**
The Consumption API returns zero results if there's no billable activity in the queried period.

---

## Solution Options

### **Option 1: Request RBAC Role Elevation (Recommended)**

This is the best solution because it enables automatic actual cost retrieval.

**Steps:**
1. Ask your subscription admin to grant you one of these roles:
   - **Billing Reader** (recommended - read-only access to billing data)
   - **Cost Management Reader** (read-only access to cost data)

2. Your admin should:
   - Go to Azure Portal → Subscriptions → Select your subscription
   - Click "Access control (IAM)" → "Add" → "Add role assignment"
   - Select "Billing Reader" or "Cost Management Reader"
   - Add your email address
   - Click "Assign"

3. Once assigned, re-run the cost assessment script:
   ```powershell
   .\AzureSubscriptionCostAssessment.ps1 -MonthsBack 12
   ```

4. The ActualCost column should now populate with real billing data.

---

### **Option 2: Import Actual Costs from Portal (Manual)**

If you cannot get role elevation, manually export costs from the Portal.

**Steps:**

#### 2a. Export Costs from Azure Portal
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to: **Cost Management + Billing** → **Cost analysis**
3. Set filters:
   - **View**: Subscription or Resource Group
   - **Date Range**: Last 3-12 months (to match your assessment)
   - **Group by**: Resource
4. Click **"Export to CSV"** (or copy data to Excel)
5. Save the file (e.g., `PortalCosts.csv`)

#### 2b. Merge Portal Costs with Assessment CSV
1. Use the provided **ImportActualCosts.ps1** script:
   ```powershell
   .\ImportActualCosts.ps1 `
     -CostAssessmentCSV "CostAssessment_DetailedCosts.csv" `
     -PortalCostExportCSV "PortalCosts.csv" `
     -OutputCSV "CostAssessment_with_ActualCosts.csv"
   ```

2. The script will:
   - Read your cost assessment CSV
   - Match Resource IDs with the Portal export
   - Update the ActualCost column
   - Generate a merged CSV

3. Verify the output shows actual costs in the new CSV file

---

### **Option 3: Hybrid Approach**

Combine both options:
1. Request role elevation (takes time for admin approval)
2. Use ImportActualCosts.ps1 immediately to work with Portal data
3. Once role is granted, re-run the script to get automated actual costs

---

## Verification Steps

### After Role Elevation
```powershell
# Verify your RBAC role
az role assignment list --assignee (az account show --query user.name -o tsv)

# Re-run the assessment
.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 12

# Check the output CSV - ActualCost should be > 0
Get-Content CostAssessment_DetailedCosts.csv | Select-Object -First 3
```

### After Importing Portal Costs
```powershell
# Run the import helper
.\ImportActualCosts.ps1 -CostAssessmentCSV "CostAssessment_DetailedCosts.csv" `
  -PortalCostExportCSV "PortalCosts.csv"

# Verify the merged CSV shows actual costs
Import-Csv "CostAssessment_DetailedCosts_with_actual_costs.csv" | 
  Where-Object ActualCost -gt 0 | 
  Measure-Object -Property ActualCost -Sum
```

---

## Expected Output Format

### Actual Costs CSV Structure
After successful integration, your CSV should show:

| ResourceId | ServiceType | EstimatedCost | ActualCost | CostVariance | MonthlyCostBreakdown |
|---|---|---|---|---|---|
| /subscriptions/.../MyVM | Virtual Machine | $36.50 | $42.15 | 15.3% | January 2026: $42.15; February 2026: $38.99 |
| /subscriptions/.../MyDB | SQL Database | $109.50 | $95.80 | -12.5% | January 2026: $48.50; February 2026: $47.30 |

- **EstimatedCost**: Based on hourly rates × 730 hrs/month
- **ActualCost**: Actual billing amount from Azure
- **CostVariance**: (Estimated - Actual) / Actual × 100 (shows estimation accuracy)
- **MonthlyCostBreakdown**: Month-by-month actual costs if available

---

## Cost Estimation Model

If actual costs remain unavailable, the script provides **estimated costs** based on:

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

These are conservative estimates. Actual costs may vary based on usage, reserved instances, discounts, etc.

---

## Troubleshooting

### "Authorization Failed" Error
**Problem**: Your account doesn't have permission to access billing data.
**Solution**: 
- Verify role assignment: `az role assignment list --assignee <your_email>`
- Request Billing Reader role from subscription admin
- Wait 5-10 minutes after role assignment (Azure caches permissions)

### "No usage data returned" Message
**Problem**: API query ran but returned no data.
**Possible Causes**:
1. No billable activity in the queried period
2. Subscription type doesn't support Consumption API
3. Resources are covered by reserved instances (may not show in usage data)

**Solutions**:
- Extend the `-MonthsBack` parameter: `.\AzureSubscriptionCostAssessment.ps1 -MonthsBack 24`
- Use Option 2 (Portal import) to get cost data
- Check Portal > Cost analysis to confirm costs exist

### ImportActualCosts Script Can't Find Resources
**Problem**: The script runs but updates 0 records.
**Possible Causes**:
1. Resource ID format mismatch between CSV files
2. Portal export uses different column names
3. Resource IDs in Portal export have different case

**Solution**:
- Verify column names in both CSVs match: `ResourceId`, `Resource ID`, or `resource id`
- Check if names are case-sensitive
- Compare first Resource ID from both files manually
- Edit portal export column headers if needed

---

## Best Practices

1. **Run Regularly**: Schedule monthly assessments to track cost trends
   ```powershell
   # Create a scheduled task to run monthly
   $trigger = New-JobTrigger -Daily -At 2AM -DaysInterval 30
   Register-ScheduledJob -Trigger $trigger -ScriptBlock { 
     .\AzureSubscriptionCostAssessment.ps1 -MonthsBack 3 
   }
   ```

2. **Archive Results**: Keep historical CSVs to track cost trends
   ```powershell
   $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
   Copy-Item "CostAssessment_DetailedCosts.csv" "Archive_CostAssessment_$timestamp.csv"
   ```

3. **Compare Estimated vs Actual**: Validate your estimation model
   - Run with actual costs enabled
   - Check CostVariance column to see estimation accuracy
   - Adjust hourly rates in the script if estimates are consistently wrong

4. **Combine with Network/Security Audits**: Use all three assessment scripts together:
   - `AzureNetworkingAudit.ps1` - Network security findings
   - `AzureSecurityAssessment.ps1` - CIS Benchmark compliance
   - `AzureSubscriptionCostAssessment.ps1` - Cost analysis

---

## Need Help?

- **Azure CLI Docs**: [Azure CLI Reference](https://learn.microsoft.com/cli/azure/)
- **Cost Management API**: [Microsoft Consumption API Docs](https://learn.microsoft.com/rest/api/consumption/)
- **RBAC Roles**: [Azure Built-in Roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)
- **Cost Analysis**: [Azure Cost Analysis Portal](https://portal.azure.com/#view/Microsoft_Azure_CostManagement/CostAnalysisV2Blade)

---

## Scripts Summary

| Script | Purpose | Output | Status |
|---|---|---|---|
| AzureNetworkingAudit.ps1 | Network security audit | CSV + Summary report | ✅ Fully functional |
| AzureSecurityAssessment.ps1 | CIS Benchmark compliance | CSV + Summary report | ✅ Fully functional |
| AzureSubscriptionCostAssessment.ps1 | Cost analysis | CSV + Summary report | ✅ Estimated costs working |
| ImportActualCosts.ps1 | Merge Portal costs | Updated CSV | ✅ Helper script |

---

**Last Updated**: February 2026  
**Version**: 1.0  
**Framework**: PowerShell 5.1, Azure CLI 2.x
