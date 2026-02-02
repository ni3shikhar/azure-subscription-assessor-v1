# Azure Virtual Networking Configuration Assessment Script

A comprehensive PowerShell script that assesses Azure virtual networking configuration based on the **CIS Microsoft Azure Foundations Benchmark** and provides findings in CSV format.

## Overview

This script automates the assessment of Azure networking security configurations by checking against multiple CIS benchmarks (5.1-5.5). It evaluates:

- Network Security Groups (NSG) configuration and rules
- Virtual Network settings and DDoS protection
- Subnets and network interfaces
- Network Watcher deployment
- Public IP allocation and SKU
- Network flow logs
- VPN/ExpressRoute connectivity
- Azure Firewall configuration
- Azure Bastion deployment
- Route tables
- Kubernetes network policies

## Prerequisites

1. **Azure CLI**: Install from https://aka.ms/azure-cli
2. **PowerShell 5.1+**: Available on Windows by default
3. **Azure Account**: Access to the Azure subscription you want to audit
4. **Permissions**: Account with Reader or higher role on the subscription

### Installation Steps

```powershell
# Install Azure CLI (if not already installed)
# Download from https://aka.ms/azure-cli or use Windows Package Manager
winget install Microsoft.AzureCLI

# Verify installation
az --version
```

## Usage

### Basic Usage

```powershell
# Run the script and use default subscription
.\AzureNetworkingAudit.ps1

# Specify a subscription ID
.\AzureNetworkingAudit.ps1 -SubscriptionId "your-subscription-id"

# Specify custom output path
.\AzureNetworkingAudit.ps1 -OutputPath "C:\Reports\AzureAudit.csv"
```

### Login to Azure

Before running the script, ensure you're logged in to Azure:

```powershell
# Interactive login
az login

# Login with a service principal
az login --service-principal -u <app-id> -p <password-or-cert> --tenant <tenant-id>
```

## CIS Controls Assessed

| Control ID | Category | Description |
|-----------|----------|-------------|
| 5.1 | NSG Logging | Enable diagnostic logging for all NSGs |
| 5.1.1 | NSG Logging | Configure NSG flow logs |
| 5.1.2 | Subnets | Configure service endpoints |
| 5.1.3 | Network Watcher | Enable Network Watcher in all regions |
| 5.1.4 | Flow Logs | Enable flow logs for all NSGs |
| 5.1.5 | Firewall | Deploy Azure Firewall |
| 5.1.6 | Connectivity | Configure VPN or ExpressRoute |
| 5.1.7 | Routing | Configure custom route tables |
| 5.2 | NSG Rules | Restrict traffic to required ports |
| 5.2.1 | RDP Access | Restrict RDP access (port 3389) |
| 5.2.2 | SSH Access | Restrict SSH access (port 22) |
| 5.2.4 | Bastion | Deploy Azure Bastion for remote access |
| 5.2.5 | Public IPs | Remove unassociated public IPs |
| 5.3 | DDoS Protection | Enable DDoS Protection Standard |
| 5.3.1 | Public IP SKU | Use Standard SKU for public IPs |
| 5.4 | Threat Intel | Enable Azure Firewall threat intelligence |
| 5.5 | K8s Policies | Enable network policies in AKS |

## Output Format

The script generates a CSV file with the following columns:

| Column | Description |
|--------|-------------|
| Category | Assessment category (NSG, Firewall, etc.) |
| Finding | Description of the finding |
| AffectedResource | Resource name that has the issue |
| Recommendation | Recommended remediation action |
| Criticality | Severity level (Critical, High, Medium, Low, Info) |
| CISControl | Associated CIS benchmark control ID |
| AssessmentDate | Timestamp of the assessment |

### Criticality Levels

- **Critical**: Immediate action required - poses significant security risk
- **High**: Should be addressed soon - represents important security gap
- **Medium**: Should be addressed - improves overall security posture
- **Low**: Nice to have - optimization and best practice
- **Info**: Informational finding - no action required

## Examples

### View Results in PowerShell

```powershell
# Display all findings
Import-Csv .\AzureNetworkingAudit_20260202_120000.csv | Format-Table -AutoSize

# Filter by criticality
Import-Csv .\AzureNetworkingAudit_20260202_120000.csv | 
  Where-Object {$_.Criticality -eq 'Critical'} | 
  Format-Table -AutoSize

# Group by category
Import-Csv .\AzureNetworkingAudit_20260202_120000.csv | 
  Group-Object Category | 
  Format-Table -AutoSize

# Export to Excel
Import-Csv .\AzureNetworkingAudit_20260202_120000.csv | 
  Export-Excel -Path .\AzureAuditReport.xlsx -AutoSize -TableName AzureFindings
```

### View Results in Excel

```powershell
# Open with Excel (requires Excel installed)
Start-Process ".\AzureNetworkingAudit_20260202_120000.csv"

# Or use Excel Online/Google Sheets for easy sharing
```

## Remediation Examples

### Enable NSG Flow Logs

```powershell
az network watcher flow-log create \
  --resource-group "myResourceGroup" \
  --enabled true \
  --nsg "myNSG" \
  --storage-account "mystorageaccount"
```

### Restrict RDP Access

```powershell
az network nsg rule create \
  --resource-group "myResourceGroup" \
  --nsg-name "myNSG" \
  --name "DenyRDPFromInternet" \
  --priority 100 \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 3389 \
  --access Deny \
  --protocol '*'
```

### Enable DDoS Protection

```powershell
az network ddos-protection create \
  --resource-group "myResourceGroup" \
  --name "myDDoSPlan"

az network vnet update \
  --resource-group "myResourceGroup" \
  --name "myVNet" \
  --ddos-protection-plan "myDDoSPlan"
```

### Deploy Azure Firewall

```powershell
# Create a subnet for the firewall
az network vnet subnet create \
  --resource-group "myResourceGroup" \
  --vnet-name "myVNet" \
  --name "AzureFirewallSubnet" \
  --address-prefix "10.0.1.0/26"

# Create and deploy firewall
az network firewall create \
  --resource-group "myResourceGroup" \
  --name "myFirewall" \
  --location "eastus"
```

### Enable Network Watcher

```powershell
az network watcher create \
  --resource-group "myResourceGroup" \
  --location "eastus"
```

## Scheduling Regular Assessments

### Option 1: Windows Task Scheduler

```powershell
# Create a scheduled task
$taskName = "Azure Networking Audit"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\scripts\AzureNetworkingAudit.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 02:00AM
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest
```

### Option 2: Azure Automation

1. Create an automation account in Azure
2. Import the PowerShell script as a runbook
3. Configure a schedule to run weekly or monthly
4. Store output in a storage account or Log Analytics

## Troubleshooting

### Error: "The subscription ... does not have valid agreements"

```powershell
# Run Azure CLI commands with proper login
az login --use-device-code

# Verify subscription access
az account list --output table
```

### Error: "Resource not found in skipped scope"

This occurs when diagnostic settings cannot be retrieved. The script continues gracefully.

### Performance Optimization

For large subscriptions:

```powershell
# Run for specific resource group
az group list --query "[?name=='myResourceGroup']" -o table

# Export results and run independently
$findings | Export-Csv -Path ".\partial-audit.csv"
```

## Best Practices

1. **Regular Assessment**: Run the script weekly or monthly
2. **Baseline Comparison**: Keep historical reports to track improvements
3. **Remediation Tracking**: Use the CSV to create remediation tickets
4. **Access Control**: Restrict report access as it contains infrastructure details
5. **Automation**: Integrate with CI/CD pipelines for continuous compliance

## Compliance Reporting

### Generate Executive Summary

```powershell
$findings = Import-Csv ".\AzureNetworkingAudit_20260202_120000.csv"

$summary = @{
    'Total Findings' = $findings.Count
    'Critical' = ($findings | Where-Object {$_.Criticality -eq 'Critical'}).Count
    'High' = ($findings | Where-Object {$_.Criticality -eq 'High'}).Count
    'Medium' = ($findings | Where-Object {$_.Criticality -eq 'Medium'}).Count
    'Compliance Score' = [math]::Round(((($findings.Count - ($findings | Where-Object {$_.Criticality -in 'Critical','High'}).Count) / $findings.Count) * 100), 2)
}

$summary
```

## References

- [CIS Microsoft Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure)
- [Azure Network Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/network-best-practices)
- [Azure Security Baseline](https://docs.microsoft.com/security/benchmark/azure)

## Support

For issues or improvements:
1. Review the CIS benchmark documentation
2. Check Azure CLI command documentation: `az network --help`
3. Verify subscription permissions and role assignments
4. Enable debug logging: `$DebugPreference = "Continue"`

## License

This script is provided as-is for Azure security assessment purposes.

## Disclaimer

This script is provided for informational purposes and should be used as part of a comprehensive security assessment. Always review findings in context of your organization's policies and security requirements.
