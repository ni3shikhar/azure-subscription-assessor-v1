# Azure Subscription Cost Assessment Script - Enhanced v2
# Comprehensive cost analysis using actual resource enumeration
# Analyzes subscription, resource group, resource type, and service type levels

param (
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [int]$MonthsBack = 12,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\AzureCostAssessment_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
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
        [decimal]$Cost,
        [string]$Currency,
        [string]$TimeFrame,
        [string]$Details,
        [string]$CostTrend,
        [decimal]$PercentageOfTotal,
        [string]$ResourceId = "N/A",
        [string]$ResourceGroup = "N/A",
        [string]$Location = "N/A",
        [string]$Tags = "N/A"
    )
    
    $global:costFindings += @{
        'AssessmentDate' = $assessmentDate
        'Level' = $Level
        'Category' = $Category
        'Name' = $Name
        'ServiceType' = $ServiceType
        'Cost' = $Cost
        'Currency' = $Currency
        'TimeFrame' = $TimeFrame
        'Details' = $Details
        'CostTrend' = $CostTrend
        'PercentageOfTotal' = $PercentageOfTotal
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
                    $rgTotalCost = 0
                    
                    foreach ($resource in $resources) {
                        try {
                            $estimatedCost = Get-EstimatedMonthlyCost -ResourceType $resource.type -Resource $resource
                            $rgTotalCost += $estimatedCost
                            $totalSubscriptionCost += $estimatedCost
                            
                            $serviceParts = $resource.type -split '/'
                            $serviceType = if ($serviceParts.Count -gt 1) { $serviceParts[0] } else { $resource.type }
                            
                            Add-CostFinding -Level "Resource" -Category $rg.name -Name $resource.name `
                                -ServiceType $serviceType -Cost $estimatedCost -Currency "USD" `
                                -TimeFrame "Monthly Estimate" `
                                -Details "Resource Type: $($resource.type), Location: $($resource.location)" `
                                -CostTrend "Estimated" -PercentageOfTotal 0 `
                                -ResourceId $resource.id -ResourceGroup $rg.name `
                                -Location $resource.location -Tags (Format-Tags $resource.tags)
                            
                            if (-not $resourceTypeMap.ContainsKey($resource.type)) {
                                $resourceTypeMap[$resource.type] = 0
                            }
                            $resourceTypeMap[$resource.type] += $estimatedCost
                            
                            if (-not $serviceTypeMap.ContainsKey($serviceType)) {
                                $serviceTypeMap[$serviceType] = 0
                            }
                            $serviceTypeMap[$serviceType] += $estimatedCost
                            
                        } catch {
                            Write-Status "      Error processing resource $($resource.name): $_"
                        }
                    }
                    
                    $rgCostsMap[$rg.name] = $rgTotalCost
                    
                    Add-CostFinding -Level "Resource Group" -Category $rg.name -Name $rg.name `
                        -ServiceType "All Services" -Cost $rgTotalCost -Currency "USD" `
                        -TimeFrame "Monthly Estimate" `
                        -Details "Total estimated monthly cost for resource group" `
                        -CostTrend "Estimated" -PercentageOfTotal 0 `
                        -ResourceId $rg.id -ResourceGroup $rg.name `
                        -Location "Multiple" -Tags "N/A"
                    
                    Write-Status "    RG Total: `$$([Math]::Round($rgTotalCost, 2))/month, Resources: $($resources.Count)"
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
            $percentage = if ($totalSubscriptionCost -gt 0) { ($service.Value / $totalSubscriptionCost) * 100 } else { 0 }
            Add-CostFinding -Level "Service Type" -Category $service.Key -Name $service.Key `
                -ServiceType $service.Key -Cost $service.Value -Currency "USD" `
                -TimeFrame "Monthly Estimate" `
                -Details "Total estimated monthly cost for service type" `
                -CostTrend "Estimated" -PercentageOfTotal $percentage `
                -ResourceId "N/A" -ResourceGroup "All RGs" -Location "N/A" -Tags "N/A"
        }
        
        # Resource Type Analysis
        Write-Status "Aggregating Resource Type costs..."
        foreach ($type in $resourceTypeMap.GetEnumerator()) {
            $percentage = if ($totalSubscriptionCost -gt 0) { ($type.Value / $totalSubscriptionCost) * 100 } else { 0 }
            Add-CostFinding -Level "Resource Type" -Category $type.Key -Name $type.Key `
                -ServiceType (($type.Key -split '/')[0]) -Cost $type.Value -Currency "USD" `
                -TimeFrame "Monthly Estimate" `
                -Details "Total estimated monthly cost for resource type" `
                -CostTrend "Estimated" -PercentageOfTotal $percentage `
                -ResourceId "N/A" -ResourceGroup "All RGs" -Location "N/A" -Tags "N/A"
        }
        
        # Subscription Total
        Write-Status "Calculating subscription totals..."
        Add-CostFinding -Level "Subscription" -Category "Total" -Name $subscriptionName `
            -ServiceType "All Services" -Cost $totalSubscriptionCost -Currency "USD" `
            -TimeFrame "Monthly Estimate" `
            -Details "Total estimated monthly cost for entire subscription" `
            -CostTrend "Estimated" -PercentageOfTotal 100 `
            -ResourceId "N/A" -ResourceGroup "Subscription" -Location "N/A" -Tags "N/A"
        
        Write-Status "  Total Estimated Monthly Cost: `$$([Math]::Round($totalSubscriptionCost, 2))"
        Write-Status "  Estimated Annual Cost: `$$([Math]::Round($totalSubscriptionCost * 12, 2))"
        
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
    
    # Export detailed costs
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

=== SUBSCRIPTION LEVEL SUMMARY ===
"@
    
    $subscriptionTotal = $global:costFindings | Where-Object { $_.Level -eq "Subscription" } | Select-Object -First 1
    if ($subscriptionTotal) {
        $summary += "`nEstimated Monthly Cost: `$$([Math]::Round($subscriptionTotal.Cost, 2))`n"
        $summary += "Estimated Annual Cost: `$$([Math]::Round($subscriptionTotal.Cost * 12, 2))`n"
    }
    
    $summary += "`n=== RESOURCE GROUP COSTS ===`n"
    $rgCosts = $global:costFindings | Where-Object { $_.Level -eq "Resource Group" } | Sort-Object -Property Cost -Descending
    foreach ($rg in $rgCosts) {
        $summary += "$($rg.Name): `$$([Math]::Round($rg.Cost, 2))`n"
    }
    
    $summary += "`n=== SERVICE TYPE COSTS ===`n"
    $serviceCosts = $global:costFindings | Where-Object { $_.Level -eq "Service Type" } | Sort-Object -Property Cost -Descending
    foreach ($service in $serviceCosts) {
        $percentage = $service.PercentageOfTotal
        $summary += "$($service.Name): `$$([Math]::Round($service.Cost, 2)) ($percentage%)`n"
    }
    
    $summary += "`n=== TOP RESOURCE TYPES BY COST ===`n"
    $typeCosts = $global:costFindings | Where-Object { $_.Level -eq "Resource Type" } | Sort-Object -Property Cost -Descending | Select-Object -First 10
    foreach ($type in $typeCosts) {
        $percentage = $type.PercentageOfTotal
        $summary += "$($type.Name): `$$([Math]::Round($type.Cost, 2)) ($percentage%)`n"
    }
    
    $summary += "`n=== RECOMMENDATIONS ===`n"
    $summary += "1. Review high-cost resource groups and identify optimization opportunities`n"
    $summary += "2. Implement resource tagging for better cost tracking and allocation`n"
    $summary += "3. Consider reserved instances for long-running resources`n"
    $summary += "4. Evaluate unused resources for deletion`n"
    $summary += "5. Monitor costs regularly for trends and anomalies`n"
    
    Set-Content -Path $summaryPath -Value $summary -Encoding UTF8
    
    Write-Status "Summary report exported to: $summaryPath"
    Write-Status "Assessment complete!"
    
} catch {
    Write-Status "Error exporting findings: $_"
}
