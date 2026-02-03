# Azure Subscription Cost Assessment Script - Enhanced v2
# Comprehensive cost analysis using actual resource enumeration
# Analyzes subscription, resource group, resource type, and service type levels

param (
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [int]$MonthsBack = 12,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot\AzureCostAssessment_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

$global:costFindings = @()
$global:resourceDetails = @()
$assessmentDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# Estimated hourly rates for common Azure resources (USD)
$resourceCosts = @{
    'Microsoft.Compute/virtualMachines' = 0.05
    'Microsoft.Sql/servers/databases' = 0.15
    'Microsoft.Storage/storageAccounts' = 0.03
    'Microsoft.KeyVault/vaults' = 1.0
    'Microsoft.Web/sites' = 0.08
    'Microsoft.Databricks/workspaces' = 0.55
    'Microsoft.Network/virtualNetworks' = 0.05
    'Microsoft.Network/networkSecurityGroups' = 0.04
    'Microsoft.Insights/components' = 0.10
    'Microsoft.OperationalInsights/workspaces' = 0.10
    'Microsoft.ContainerRegistry/registries' = 0.10
    'Microsoft.ContainerService/managedClusters' = 0.10
}

function Add-CostFinding {
    param (
        [string]$Level,
        [string]$Category,
        [string]$Name,
        [string]$ServiceType,
        [decimal]$EstimatedCost,
        [decimal]$ActualCost = 0,
        [string]$Currency = "USD",
        [string]$TimeFrame,
        [string]$Details,
        [string]$CostTrend,
        [decimal]$PercentageOfTotal,
        [string]$ResourceId = "N/A",
        [string]$ResourceGroup = "N/A",
        [string]$Location = "N/A",
        [string]$Tags = "N/A"
    )
    
    $variance = if ($ActualCost -gt 0) { (($EstimatedCost - $ActualCost) / $ActualCost * 100) } else { 0 }
    
    $global:costFindings += [PSCustomObject]@{
        'AssessmentDate' = $assessmentDate
        'Level' = $Level
        'Category' = $Category
        'Name' = $Name
        'ServiceType' = $ServiceType
        'EstimatedCost' = [Math]::Round($EstimatedCost, 2)
        'ActualCost' = [Math]::Round($ActualCost, 2)
        'CostVariance' = [Math]::Round($variance, 2)
        'Currency' = $Currency
        'TimeFrame' = $TimeFrame
        'MonthlyCostBreakdown' = if ($TimeFrame -like "Monthly Details:*") { $TimeFrame -replace "Monthly Details: ", "" } else { "N/A" }
        'Details' = $Details
        'CostTrend' = $CostTrend
        'PercentageOfTotal' = [Math]::Round($PercentageOfTotal, 2)
        'ResourceId' = $ResourceId
        'ResourceGroup' = $ResourceGroup
        'Location' = $Location
        'Tags' = $Tags
    }
}

function Get-EstimatedMonthlyCost {
    param(
        [string]$ResourceType,
        [object]$Resource
    )
    
    $hourlyRate = $resourceCosts[$ResourceType]
    if (-not $hourlyRate) {
        $hourlyRate = 0.05  # Default estimate
    }
    
    # Calculate monthly cost (730 hours average per month)
    $monthlyCost = $hourlyRate * 730
    
    # Adjust based on resource-specific properties
    switch ($ResourceType) {
        'Microsoft.Storage/storageAccounts' {
            # Add estimated data storage cost
            $monthlyCost += 2.4
        }
    }
    
    return $monthlyCost
}

function Format-Tags {
    param([object]$Tags)
    
    if (-not $Tags) {
        return "None"
    }
    
    $tagStrings = @()
    foreach ($tag in $Tags.PSObject.Properties) {
        $tagStrings += "$($tag.Name)=$($tag.Value)"
    }
    
    return ($tagStrings -join "; ")
}

function Convert-MonthKeyToName {
    param([string]$MonthKey)
    
    try {
        # Handle format like "202312" or "2023-12"
        $monthKey = $monthKey -replace '[^0-9]', ''
        
        if ($monthKey.Length -eq 6) {
            $year = $monthKey.Substring(0, 4)
            $month = $monthKey.Substring(4, 2)
            $date = [DateTime]::ParseExact("$year-$month", "yyyy-MM", [System.Globalization.CultureInfo]::InvariantCulture)
            return $date.ToString("MMMM yyyy")
        }
    } catch {
        return $monthKey
    }
    
    return $monthKey
}

function Get-ActualMonthlyCosts {
    param(
        [string]$ResourceId,
        [int]$MonthsBack,
        [string]$SubscriptionId
    )
    
    try {
        $monthlyCosts = @{}
        
        # Query actual costs from Azure Cost Management API at subscription level
        $endDate = Get-Date -Format "yyyy-MM-dd"
        $startDate = (Get-Date).AddDays(-($MonthsBack * 30)).ToString("yyyy-MM-dd")
        
        # Use simpler query without resource filter first
        $queryJson = @{
            'type' = 'Usage'
            'timeframe' = 'Custom'
            'timePeriod' = @{
                'from' = "${startDate}T00:00:00Z"
                'to' = "${endDate}T23:59:59Z"
            }
            'granularity' = 'Monthly'
            'grouping' = @(
                @{
                    'type' = 'dimension'
                    'name' = 'ResourceId'
                }
            )
            'aggregation' = @{
                'totalCost' = @{
                    'name' = 'PreTaxCost'
                    'function' = 'Sum'
                }
            }
        } | ConvertTo-Json -Depth 10
        
        $costData = az costmanagement query --scope "/subscriptions/$SubscriptionId" --query-expression $queryJson 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($costData -and $costData.properties.rows) {
            foreach ($row in $costData.properties.rows) {
                $month = $row[0]
                $resourceIdFromData = $row[1]
                $cost = [decimal]$row[2]
                
                # Check if this row matches our resource
                if ($resourceIdFromData -eq $ResourceId) {
                    $monthName = Convert-MonthKeyToName -MonthKey $month
                    $monthlyCosts[$monthName] = [Math]::Round($cost, 2)
                }
            }
        }
        
        return $monthlyCosts
    } catch {
        Write-Status "  Warning: Could not retrieve actual cost for resource: $_"
        return @{}
    }
}

function Get-ActualMonthlyCosts {
    param(
        [string]$ResourceId,
        [int]$MonthsBack,
        [string]$SubscriptionId,
        [hashtable]$CostsCache
    )
    
    try {
        $monthlyCosts = @{}
        
        if ($CostsCache -and $CostsCache.Count -gt 0) {
            foreach ($key in $CostsCache.Keys) {
                if ($key -like "$([regex]::Escape($ResourceId))|*") {
                    $monthPart = $key -replace "^.*\|", ""
                    $monthName = Convert-MonthKeyToName -MonthKey $monthPart
                    $cost = $CostsCache[$key]
                    $monthlyCosts[$monthName] = $cost
                }
            }
        }
        
        return $monthlyCosts
    } catch {
        return @{}
    }
}

function Get-SubscriptionActualCosts {
    param(
        [string]$SubscriptionId,
        [int]$MonthsBack
    )
    
    try {
        $costsByResourceId = @{}
        
        # Calculate date range
        $endDate = Get-Date -Format "yyyy-MM-dd"
        $startDate = (Get-Date).AddDays(-($MonthsBack * 30)).ToString("yyyy-MM-dd")
        
        # Build filter parameter for Consumption API
        $filter = "`$filter=properties/usageStart ge '$startDate' AND properties/usageEnd le '$endDate'"
        
        # Query using Consumption API with proper filter (for Web Direct subscriptions)
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/usageDetails?api-version=2021-10-01&`$filter=properties/usageStart ge '$startDate'"
        
        Write-Status "Querying Azure Consumption API for actual costs..."
        Write-Status "  Period: $startDate to $endDate" -WriteToConsole $false
        
        $apiOutput = az rest --method get --uri $uri 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = ($apiOutput | Out-String).Trim()
            if ($errorMsg -like "*400*Bad Request*") {
                Write-Status "API Parameter Error: Using Web Direct subscription format"
                Write-Status "  The API requires specific date filters for Web Direct subscriptions"
                Write-Status "  This is expected - use ImportActualCosts.ps1 with Portal data instead"
            } elseif ($errorMsg -like "*AuthorizationFailed*" -or $errorMsg -like "*insufficient*") {
                Write-Status "Access Denied: Your account lacks permission to view billing data."
                Write-Status "  Required role: Billing Reader, Owner, or Cost Management Reader"
                Write-Status "  Contact your subscription admin to grant the required role."
            } elseif ($errorMsg -like "*not found*") {
                Write-Status "API endpoint not accessible. Check subscription type and permissions."
            } else {
                Write-Status "API Error: Consumption API call failed"
                Write-Status "  Message: $($errorMsg.Substring(0, [Math]::Min(200, $errorMsg.Length)))"
            }
            Write-Status "  Use ImportActualCosts.ps1 to merge Portal costs with this assessment"
            return @{}
        }
        
        $result = $apiOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($result -and $result.value -and $result.value.Count -gt 0) {
            Write-Status "Retrieved $($result.value.Count) usage entries from Consumption API"
            
            foreach ($item in $result.value) {
                if ($item.properties -and $item.properties.resourceId) {
                    $resourceId = $item.properties.resourceId
                    $cost = [decimal]$item.properties.pretaxCost
                    $usageDate = $item.properties.usageStart
                    
                    if ($cost -gt 0) {
                        $monthKey = $usageDate -replace "^(\d{4}-\d{2}).*", '\$1'
                        $key = "$resourceId|$monthKey"
                        
                        if (-not $costsByResourceId.ContainsKey($key)) {
                            $costsByResourceId[$key] = [Math]::Round($cost, 2)
                        } else {
                            $costsByResourceId[$key] += [Math]::Round($cost, 2)
                        }
                    }
                }
            }
            
            Write-Status "Found actual costs for $([int]($costsByResourceId.Keys.Count / $MonthsBack)) resources"
        } else {
            Write-Status "No usage data in Consumption API response for the specified period."
            Write-Status "  This may indicate:"
            Write-Status "    • No billable usage in the period (check Portal > Cost analysis)"
            Write-Status "    • Your account lacks access to billing APIs"
            Write-Status "    • The subscription type doesn't support API access"
            Write-Status "  Use ImportActualCosts.ps1 to merge costs from Azure Portal export"
        }
        
        return $costsByResourceId
    } catch {
        Write-Status "Note: Unable to retrieve actual costs from Consumption API"
        Write-Status "  Error: $($_.Exception.Message)"
        Write-Status "  Alternative: Use ImportActualCosts.ps1 with costs from Azure Portal"
        return @{}
    }
}

function Write-Status {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss'): $Message" -ForegroundColor Cyan
}

# Main Assessment Logic
Write-Status "Starting Azure Subscription Cost Assessment"

if ($SubscriptionId) {
    Write-Status "Setting subscription context to: $SubscriptionId"
    az account set --subscription $SubscriptionId 2>$null
}

$currentSubscription = az account show --query 'id' -o tsv 2>$null
$subscriptionName = az account show --query 'name' -o tsv 2>$null

Write-Status "Analyzing subscription: $subscriptionName (ID: $currentSubscription)"
Write-Status "Analysis period: Last $MonthsBack months"
Write-Status "Note: Install 'az costmanagement' extension for actual billing costs: az extension add --name costmanagement"

# Retrieve actual subscription costs grouped by resource
Write-Status "Retrieving actual cost data from Azure Cost Management..."
$subscriptionCostsCache = Get-SubscriptionActualCosts -SubscriptionId $currentSubscription -MonthsBack $MonthsBack

# ===========================
# RESOURCE GROUP AND RESOURCE ANALYSIS
# ===========================
Write-Status "Analyzing resources across resource groups..."

try {
    $resourceGroups = az group list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $resourceGroups -or $resourceGroups.Count -eq 0) {
        Write-Status "  No resource groups found"
    } else {
        $rgCostsMap = @{}
        $resourceTypeMap = @{}
        $serviceTypeMap = @{}
        $totalSubscriptionCost = 0
        
        foreach ($rg in $resourceGroups) {
            Write-Status "  Processing Resource Group: $($rg.name)"
            
            try {
                $resources = az resource list --resource-group $rg.name --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($resources) {
                    $rgTotalEstimatedCost = 0
                    $rgTotalActualCost = 0
                    
                    foreach ($resource in $resources) {
                        try {
                            $estimatedCost = Get-EstimatedMonthlyCost -ResourceType $resource.type -Resource $resource
                            
                            # Get actual cost from cached subscription data
                            $monthlyCosts = Get-ActualMonthlyCosts -ResourceId $resource.id -MonthsBack $MonthsBack -SubscriptionId $currentSubscription -CostsCache $subscriptionCostsCache
                            $actualCost = ($monthlyCosts.Values | Measure-Object -Sum).Sum
                            
                            $rgTotalEstimatedCost += $estimatedCost
                            $rgTotalActualCost += $actualCost
                            $totalSubscriptionCost += $estimatedCost
                            
                            $serviceParts = $resource.type -split '/'
                            $serviceType = if ($serviceParts.Count -gt 1) { $serviceParts[0] } else { $resource.type }
                            
                            $monthlyDetails = ""
                            foreach ($month in ($monthlyCosts.Keys | Sort-Object)) {
                                $monthlyDetails += "$month`: $$($monthlyCosts[$month]); "
                            }
                            if ($monthlyDetails) {
                                $monthlyDetails = $monthlyDetails.TrimEnd('; ')
                            } else {
                                $monthlyDetails = "No actual cost data available"
                            }
                            
                            Add-CostFinding -Level "Resource" -Category $rg.name -Name $resource.name `
                                -ServiceType $serviceType -EstimatedCost $estimatedCost -ActualCost $actualCost `
                                -TimeFrame "Monthly Details: $monthlyDetails" `
                                -Details "Resource Type: $($resource.type), Location: $($resource.location)" `
                                -CostTrend "Actual" -PercentageOfTotal 0 `
                                -ResourceId $resource.id -ResourceGroup $rg.name `
                                -Location $resource.location -Tags (Format-Tags $resource.tags)
                            
                            if (-not $resourceTypeMap.ContainsKey($resource.type)) {
                                $resourceTypeMap[$resource.type] = @{ 'Estimated' = 0; 'Actual' = 0 }
                            }
                            $resourceTypeMap[$resource.type]['Estimated'] += $estimatedCost
                            $resourceTypeMap[$resource.type]['Actual'] += $actualCost
                            
                            if (-not $serviceTypeMap.ContainsKey($serviceType)) {
                                $serviceTypeMap[$serviceType] = @{ 'Estimated' = 0; 'Actual' = 0 }
                            }
                            $serviceTypeMap[$serviceType]['Estimated'] += $estimatedCost
                            $serviceTypeMap[$serviceType]['Actual'] += $actualCost
                            
                        } catch {
                            Write-Status "      Error processing resource $($resource.name): $_"
                        }
                    }
                    
                    $rgCostsMap[$rg.name] = @{ 'Estimated' = $rgTotalEstimatedCost; 'Actual' = $rgTotalActualCost }
                    
                    Add-CostFinding -Level "Resource Group" -Category $rg.name -Name $rg.name `
                        -ServiceType "All Services" -EstimatedCost $rgTotalEstimatedCost -ActualCost $rgTotalActualCost `
                        -TimeFrame "Monthly" `
                        -Details "Total estimated monthly cost for resource group" `
                        -CostTrend "Estimated" -PercentageOfTotal 0 `
                        -ResourceId $rg.id -ResourceGroup $rg.name `
                        -Location "Multiple" -Tags "N/A"
                    
                    Write-Status "    RG Total - Estimated: `$$([Math]::Round($rgTotalEstimatedCost, 2))/month, Actual: `$$([Math]::Round($rgTotalActualCost, 2))/month, Resources: $($resources.Count)"
                } else {
                    Write-Status "    No resources found in RG"
                }
            } catch {
                Write-Status "    Error analyzing RG: $_"
            }
        }
        
        # Service Type Analysis
        Write-Status "Aggregating Service Type costs..."
        foreach ($service in $serviceTypeMap.GetEnumerator()) {
            $estimatedTotal = $service.Value['Estimated']
            $actualTotal = $service.Value['Actual']
            $percentage = if ($totalSubscriptionCost -gt 0) { ($estimatedTotal / $totalSubscriptionCost) * 100 } else { 0 }
            Add-CostFinding -Level "Service Type" -Category $service.Key -Name $service.Key `
                -ServiceType $service.Key -EstimatedCost $estimatedTotal -ActualCost $actualTotal `
                -TimeFrame "Monthly" `
                -Details "Total monthly cost for service type (Estimated vs Actual)" `
                -CostTrend "Mixed" -PercentageOfTotal $percentage `
                -ResourceId "N/A" -ResourceGroup "All RGs" -Location "N/A" -Tags "N/A"
        }
        
        # Resource Type Analysis
        Write-Status "Aggregating Resource Type costs..."
        foreach ($type in $resourceTypeMap.GetEnumerator()) {
            $estimatedTotal = $type.Value['Estimated']
            $actualTotal = $type.Value['Actual']
            $percentage = if ($totalSubscriptionCost -gt 0) { ($estimatedTotal / $totalSubscriptionCost) * 100 } else { 0 }
            Add-CostFinding -Level "Resource Type" -Category $type.Key -Name $type.Key `
                -ServiceType (($type.Key -split '/')[0]) -EstimatedCost $estimatedTotal -ActualCost $actualTotal `
                -TimeFrame "Monthly" `
                -Details "Total monthly cost for resource type (Estimated vs Actual)" `
                -CostTrend "Mixed" -PercentageOfTotal $percentage `
                -ResourceId "N/A" -ResourceGroup "All RGs" -Location "N/A" -Tags "N/A"
        }
        
        # Subscription Total
        Write-Status "Calculating subscription totals..."
        $totalSubscriptionActualCost = ($global:costFindings | Where-Object { $_.Level -eq "Resource" } | Measure-Object -Property ActualCost -Sum).Sum
        
        Add-CostFinding -Level "Subscription" -Category "Total" -Name $subscriptionName `
            -ServiceType "All Services" -EstimatedCost $totalSubscriptionCost -ActualCost $totalSubscriptionActualCost `
            -TimeFrame "Monthly" `
            -Details "Total monthly cost for entire subscription (Estimated vs Actual)" `
            -CostTrend "Mixed" -PercentageOfTotal 100 `
            -ResourceId "N/A" -ResourceGroup "Subscription" -Location "N/A" -Tags "N/A"
        
        Write-Status "  Total Estimated Monthly Cost: `$$([Math]::Round($totalSubscriptionCost, 2))"
        Write-Status "  Total Actual Monthly Cost: `$$([Math]::Round($totalSubscriptionActualCost, 2))"
        Write-Status "  Estimated Annual Cost: `$$([Math]::Round($totalSubscriptionCost * 12, 2))"
        Write-Status "  Actual Annual Cost: `$$([Math]::Round($totalSubscriptionActualCost * 12, 2))"
        
    }
} catch {
    Write-Status "  Error in resource analysis: $_"
}

# ===========================
# EXPORT FINDINGS TO CSV
# ===========================
Write-Status "Exporting findings to CSV..."

try {
    # Ensure output directory exists
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Export detailed costs directly (already PSCustomObjects with monthly details)
    $csvPath = "$OutputPath\CostAssessment_DetailedCosts.csv"
    $global:costFindings | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
    
    Write-Status "Detailed costs exported to: $csvPath"
    Write-Status "Total findings: $($global:costFindings.Count)"
    
    # Generate Summary Report
    $summaryPath = "$OutputPath\CostAssessment_Summary.txt"
    $summary = @"
Azure Subscription Cost Assessment Report
Assessment Date: $assessmentDate
Subscription: $subscriptionName (ID: $currentSubscription)
Analysis Period: Last $MonthsBack months

IMPORTANT NOTE - ACTUAL COSTS:
- Estimated costs are based on hourly resource rates (see resource cost mapping below)
- Actual billing costs require one of these:
  1. Billing Reader or Owner role on the subscription (to access Consumption API)
  2. Manually export costs from Azure Portal and merge with this CSV
  
HOW TO ADD ACTUAL COSTS FROM AZURE PORTAL:
1. Go to Azure Portal > Cost Management + Billing > Cost analysis
2. Filter by "Subscription", "Resource Group", and "Last 3 Months"
3. Export the data to CSV
4. In the exported CSV, find your resource ID and its cost
5. In this script's output CSV, update the "ActualCost" column with Portal data
6. The "MonthlyCostBreakdown" field should show actual monthly amounts

REQUIRED ROLE FOR API ACCESS:
- Ensure your account has "Billing Reader" or "Owner" role on the subscription
- Check in Azure Portal > Subscriptions > IAM > Role assignments

=== SUBSCRIPTION LEVEL SUMMARY ===
"@
    
    $subscriptionTotal = $global:costFindings | Where-Object { $_.Level -eq "Subscription" } | Select-Object -First 1
    if ($subscriptionTotal) {
        $summary += "`nEstimated Monthly Cost: `$$($subscriptionTotal.EstimatedCost)`n"
        $summary += "Actual Monthly Cost: `$$($subscriptionTotal.ActualCost)`n"
        $summary += "Cost Variance: $($subscriptionTotal.CostVariance)%`n"
        $summary += "`nEstimated Annual Cost: `$$([Math]::Round($subscriptionTotal.EstimatedCost * 12, 2))`n"
        $summary += "Actual Annual Cost: `$$([Math]::Round($subscriptionTotal.ActualCost * 12, 2))`n"
    }
    
    $summary += "`n=== RESOURCE LEVEL COSTS WITH MONTHLY BREAKDOWN ===`n"
    $resourceCosts = $global:costFindings | Where-Object { $_.Level -eq "Resource" } | Sort-Object -Property ActualCost -Descending | Select-Object -First 20
    foreach ($resource in $resourceCosts) {
        $summary += "$($resource.Name) (RG: $($resource.ResourceGroup)):`n"
        $summary += "  Estimated Monthly: `$$($resource.EstimatedCost) | Actual Total: `$$($resource.ActualCost) | Variance: $($resource.CostVariance)%`n"
        $summary += "  Monthly Breakdown: $($resource.TimeFrame)`n"
        $summary += "  Details: $($resource.Details)`n`n"
    }
    
    $summary += "`n=== RESOURCE GROUP COSTS (Estimated vs Actual) ===`n"
    $rgCosts = $global:costFindings | Where-Object { $_.Level -eq "Resource Group" } | Sort-Object -Property EstimatedCost -Descending
    foreach ($rg in $rgCosts) {
        $summary += "$($rg.Name):`n"
        $summary += "  Estimated: `$$($rg.EstimatedCost) | Actual: `$$($rg.ActualCost) | Variance: $($rg.CostVariance)%`n"
    }
    
    $summary += "`n=== SERVICE TYPE COSTS (Estimated vs Actual) ===`n"
    $serviceCosts = $global:costFindings | Where-Object { $_.Level -eq "Service Type" } | Sort-Object -Property EstimatedCost -Descending
    foreach ($service in $serviceCosts) {
        $percentage = $service.PercentageOfTotal
        $summary += "$($service.Name):`n"
        $summary += "  Estimated: `$$($service.EstimatedCost) | Actual: `$$($service.ActualCost) | Variance: $($service.CostVariance)% | % of Total: $percentage%`n"
    }
    
    $summary += "`n=== TOP RESOURCE TYPES BY ESTIMATED COST ===`n"
    $typeCosts = $global:costFindings | Where-Object { $_.Level -eq "Resource Type" } | Sort-Object -Property EstimatedCost -Descending | Select-Object -First 10
    foreach ($type in $typeCosts) {
        $percentage = $type.PercentageOfTotal
        $summary += "$($type.Name):`n"
        $summary += "  Estimated: `$$($type.EstimatedCost) | Actual: `$$($type.ActualCost) | Variance: $($type.CostVariance)% | % of Total: $percentage%`n"
    }
    
    $summary += "`n=== COST ANALYSIS INSIGHTS ===`n"
    $summary += "- Estimated costs are based on hourly rates multiplied by 730 hours/month`n"
    $summary += "- Hourly rate mapping (used for estimation):`n"
    $summary += "  * Virtual Machines: `$0.05/hr = `$36.50/month`n"
    $summary += "  * SQL Databases: `$0.15/hr = `$109.50/month`n"
    $summary += "  * Storage Accounts: `$0.03/hr = `$21.90/month + storage data costs`n"
    $summary += "  * Key Vault: `$1.00/hr = `$730.00/month`n"
    $summary += "  * App Service: `$0.08/hr = `$58.40/month`n"
    $summary += "  * Databricks: `$0.55/hr = `$401.50/month`n"
    $summary += "  * Network VNet: `$0.05/hr = `$36.50/month`n"
    $summary += "  * NSG: `$0.04/hr = `$29.20/month`n"
    $summary += "  * Application Insights: `$0.10/hr = `$73.00/month`n"
    $summary += "  * Log Analytics: `$0.10/hr = `$73.00/month`n"
    $summary += "  * Container Registry: `$0.10/hr = `$73.00/month`n"
    $summary += "  * AKS: `$0.10/hr = `$73.00/month`n"
    $summary += "- For actual costs, install costmanagement extension and check Azure Portal`n"
    
    $summary += "`n=== RECOMMENDATIONS ===`n"
    $summary += "1. Review cost variance percentages to improve estimation accuracy`n"
    $summary += "2. Investigate resource groups with high actual costs for optimization`n"
    $summary += "3. Focus on high-percentage service types for cost reduction opportunities`n"
    $summary += "4. Implement resource tagging for better cost tracking and allocation`n"
    $summary += "5. Consider reserved instances for long-running resources`n"
    $summary += "6. Evaluate unused resources for deletion`n"
    $summary += "7. Monitor costs regularly for trends and anomalies`n"
    
    Set-Content -Path $summaryPath -Value $summary -Encoding UTF8
    
    Write-Status "Summary report exported to: $summaryPath"
    Write-Status "Assessment complete!"
    
} catch {
    Write-Status "Error exporting findings: $_"
}
