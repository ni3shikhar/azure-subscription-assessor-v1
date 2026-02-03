# Azure Subscription Cost Assessment Script - Enhanced
# Comprehensive cost analysis including resource details and estimated costs
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

function Get-AzureCostData {
    param (
        [string]$SubscriptionId,
        [int]$DaysBack,
        [string]$Granularity = "Monthly",
        [string]$GroupByDimension = $null
    )
    
    try {
        $today = Get-Date
        $startDate = $today.AddDays(-$DaysBack).ToString("yyyy-MM-dd")
        $endDate = $today.ToString("yyyy-MM-dd")
        
        $queryParams = @{
            'type'  = 'Usage'
            'timeframe' = 'Custom'
            'timePeriod' = @{
                'from' = "$($startDate)T00:00:00Z"
                'to'   = "$($endDate)T23:59:59Z"
            }
            'granularity' = $Granularity
            'grouping' = @(
                @{
                    'type' = $GroupByDimension
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $scope = "/subscriptions/$SubscriptionId"
        
        $result = az costmanagement query --scope $scope --query-expression $queryParams 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        return $result
    } catch {
        Write-Status "  Error retrieving cost data: $_"
        return $null
    }
}

function ConvertTo-MonthlyFormat {
    param([string]$DateString)
    if ($DateString -match '(\d{4})-(\d{2})') {
        return [DateTime]::ParseExact($DateString.Substring(0,7), 'yyyy-MM', [System.Globalization.CultureInfo]::InvariantCulture).ToString('MMM yyyy')
    }
    return $DateString
}

Write-Status "Starting Azure Subscription Cost Assessment"

if ($SubscriptionId) {
    Write-Status "Setting subscription context to: $SubscriptionId"
    az account set --subscription $SubscriptionId
}

$currentSubscription = az account show --query 'id' -o tsv 2>$null
$subscriptionName = az account show --query 'name' -o tsv 2>$null

Write-Status "Analyzing subscription: $subscriptionName (ID: $currentSubscription)"
Write-Status "Analysis period: Last $MonthsBack months"

# ===========================
# SUBSCRIPTION LEVEL COSTS
# ===========================
Write-Status "Analyzing subscription-level costs..."

try {
    $today = Get-Date
    $startDate = $today.AddDays(-($MonthsBack * 30)).ToString("yyyy-MM-dd")
    $endDate = $today.ToString("yyyy-MM-dd")
    
    # Get total subscription costs
    $scope = "/subscriptions/$currentSubscription"
    $queryExpression = @{
        'type'      = 'Usage'
        'timeframe' = 'Custom'
        'timePeriod' = @{
            'from' = "$($startDate)T00:00:00Z"
            'to'   = "$($endDate)T23:59:59Z"
        }
        'granularity' = 'Monthly'
        'grouping'  = @()
        'aggregation' = @{
            'totalCost' = @{
                'name' = 'PreTaxCost'
                'function' = 'Sum'
            }
        }
    } | ConvertTo-Json -Depth 10
    
    $result = az costmanagement query --scope $scope --query-expression $queryExpression 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($result -and $result.properties.rows) {
        $totalCost = 0
        $monthlyData = @()
        
        foreach ($row in $result.properties.rows) {
            $month = $row[0]
            $cost = [decimal]$row[1]
            $totalCost += $cost
            
            $monthlyData += @{
                'Month' = (ConvertTo-MonthlyFormat $month)
                'Cost' = $cost
            }
            
            Add-CostFinding -Level "Subscription" -Category "Monthly Cost" -Name $subscriptionName `
                -ServiceType "All Services" -Cost $cost -Currency "USD" `
                -TimeFrame (ConvertTo-MonthlyFormat $month) `
                -Details "Monthly recurring cost" `
                -CostTrend "Monthly" -PercentageOfTotal 100
        }
        
        Write-Status "  Total subscription cost for period: `$$([Math]::Round($totalCost, 2))"
        
        # Calculate average monthly cost
        $avgMonthlyCost = if ($monthlyData.Count -gt 0) { $totalCost / $monthlyData.Count } else { 0 }
        Write-Status "  Average monthly cost: `$$([Math]::Round($avgMonthlyCost, 2))"
        
        # Identify cost trend
        if ($monthlyData.Count -ge 2) {
            $firstMonth = $monthlyData[0].Cost
            $lastMonth = $monthlyData[-1].Cost
            $costChange = $lastMonth - $firstMonth
            $percentChange = if ($firstMonth -ne 0) { ($costChange / $firstMonth) * 100 } else { 0 }
            
            if ($costChange -gt 0) {
                Write-Status "  Cost trend: INCREASING ($(([Math]::Abs($percentChange)).ToString("F2"))% increase)" -ForegroundColor Yellow
            } elseif ($costChange -lt 0) {
                Write-Status "  Cost trend: DECREASING ($([Math]::Abs($percentChange).ToString("F2"))% decrease)" -ForegroundColor Green
            } else {
                Write-Status "  Cost trend: STABLE (No significant change)"
            }
        }
        
    } else {
        Write-Status "  No cost data available at subscription level"
    }
    
} catch {
    Write-Status "  Error analyzing subscription costs: $_"
}

# ===========================
# RESOURCE GROUP LEVEL COSTS
# ===========================
Write-Status "Analyzing resource group-level costs..."

try {
    $resourceGroups = az group list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $resourceGroups -or $resourceGroups.Count -eq 0) {
        Write-Status "  No resource groups found"
    } else {
        $rgCosts = @()
        
        foreach ($rg in $resourceGroups) {
            Write-Status "  Analyzing Resource Group: $($rg.name)"
            
            try {
                $scope = "/subscriptions/$currentSubscription/resourceGroups/$($rg.name)"
                
                $queryExpression = @{
                    'type'      = 'Usage'
                    'timeframe' = 'Custom'
                    'timePeriod' = @{
                        'from' = "$($startDate)T00:00:00Z"
                        'to'   = "$($endDate)T23:59:59Z"
                    }
                    'granularity' = 'Monthly'
                    'grouping'  = @()
                    'aggregation' = @{
                        'totalCost' = @{
                            'name' = 'PreTaxCost'
                            'function' = 'Sum'
                        }
                    }
                } | ConvertTo-Json -Depth 10
                
                $rgResult = az costmanagement query --scope $scope --query-expression $queryExpression 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($rgResult -and $rgResult.properties.rows) {
                    $rgTotalCost = 0
                    
                    foreach ($row in $rgResult.properties.rows) {
                        $month = $row[0]
                        $cost = [decimal]$row[1]
                        $rgTotalCost += $cost
                        
                        Add-CostFinding -Level "Resource Group" -Category $rg.name -Name $rg.name `
                            -ServiceType "All Services" -Cost $cost -Currency "USD" `
                            -TimeFrame (ConvertTo-MonthlyFormat $month) `
                            -Details "RG monthly cost" `
                            -CostTrend "Monthly" -PercentageOfTotal 0
                    }
                    
                    $rgCosts += @{
                        'Name' = $rg.name
                        'TotalCost' = $rgTotalCost
                        'AvgMonthlyCost' = $rgTotalCost / $rgResult.properties.rows.Count
                    }
                    
                    Write-Status "    Total cost: `$$([Math]::Round($rgTotalCost, 2))"
                }
            } catch {
                Write-Status "    Error analyzing RG: $_"
            }
        }
        
        # Sort and display top RGs
        if ($rgCosts.Count -gt 0) {
            $topRgs = $rgCosts | Sort-Object -Property TotalCost -Descending | Select-Object -First 5
            Write-Status "  Top 5 Resource Groups by cost:"
            foreach ($topRg in $topRgs) {
                Write-Status "    - $($topRg.Name): `$$([Math]::Round($topRg.TotalCost, 2))"
            }
        }
    }
    
} catch {
    Write-Status "  Error analyzing resource group costs: $_"
}

# ===========================
# SERVICE TYPE LEVEL COSTS
# ===========================
Write-Status "Analyzing service type-level costs..."

try {
    $scope = "/subscriptions/$currentSubscription"
    
    $queryExpression = @{
        'type'      = 'Usage'
        'timeframe' = 'Custom'
        'timePeriod' = @{
            'from' = "$($startDate)T00:00:00Z"
            'to'   = "$($endDate)T23:59:59Z"
        }
        'granularity' = 'Monthly'
        'grouping'  = @(
            @{
                'type' = 'dimension'
                'name' = 'MeterCategory'
            }
        )
        'aggregation' = @{
            'totalCost' = @{
                'name' = 'PreTaxCost'
                'function' = 'Sum'
            }
        }
    } | ConvertTo-Json -Depth 10
    
    $serviceResult = az costmanagement query --scope $scope --query-expression $queryExpression 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($serviceResult -and $serviceResult.properties.rows) {
        $serviceCosts = @{}
        $totalServiceCost = 0
        
        foreach ($row in $serviceResult.properties.rows) {
            $month = $row[0]
            $service = $row[1]
            $cost = [decimal]$row[2]
            
            if (-not $serviceCosts.ContainsKey($service)) {
                $serviceCosts[$service] = 0
            }
            $serviceCosts[$service] += $cost
            $totalServiceCost += $cost
            
            Add-CostFinding -Level "Service Type" -Category $service -Name $service `
                -ServiceType $service -Cost $cost -Currency "USD" `
                -TimeFrame (ConvertTo-MonthlyFormat $month) `
                -Details "Service monthly cost" `
                -CostTrend "Monthly" -PercentageOfTotal 0
        }
        
        # Sort services by cost
        $sortedServices = $serviceCosts.GetEnumerator() | Sort-Object -Property Value -Descending
        
        Write-Status "  Services by total cost:"
        foreach ($service in $sortedServices | Select-Object -First 10) {
            $percentage = if ($totalServiceCost -gt 0) { ($service.Value / $totalServiceCost) * 100 } else { 0 }
            Write-Status "    - $($service.Name): `$$([Math]::Round($service.Value, 2)) ($([Math]::Round($percentage, 2))%)"
        }
        
    } else {
        Write-Status "  No service-level cost data available"
    }
    
} catch {
    Write-Status "  Error analyzing service type costs: $_"
}

# ===========================
# RESOURCE TYPE LEVEL COSTS
# ===========================
Write-Status "Analyzing resource type-level costs..."

try {
    $scope = "/subscriptions/$currentSubscription"
    
    $queryExpression = @{
        'type'      = 'Usage'
        'timeframe' = 'Custom'
        'timePeriod' = @{
            'from' = "$($startDate)T00:00:00Z"
            'to'   = "$($endDate)T23:59:59Z"
        }
        'granularity' = 'Monthly'
        'grouping'  = @(
            @{
                'type' = 'dimension'
                'name' = 'ResourceType'
            }
        )
        'aggregation' = @{
            'totalCost' = @{
                'name' = 'PreTaxCost'
                'function' = 'Sum'
            }
        }
    } | ConvertTo-Json -Depth 10
    
    $typeResult = az costmanagement query --scope $scope --query-expression $queryExpression 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($typeResult -and $typeResult.properties.rows) {
        $typeCosts = @{}
        $totalTypeCost = 0
        
        foreach ($row in $typeResult.properties.rows) {
            $month = $row[0]
            $type = $row[1]
            $cost = [decimal]$row[2]
            
            if (-not $typeCosts.ContainsKey($type)) {
                $typeCosts[$type] = 0
            }
            $typeCosts[$type] += $cost
            $totalTypeCost += $cost
            
            Add-CostFinding -Level "Resource Type" -Category $type -Name $type `
                -ServiceType "N/A" -Cost $cost -Currency "USD" `
                -TimeFrame (ConvertTo-MonthlyFormat $month) `
                -Details "Resource type monthly cost" `
                -CostTrend "Monthly" -PercentageOfTotal 0
        }
        
        # Sort resources by cost
        $sortedTypes = $typeCosts.GetEnumerator() | Sort-Object -Property Value -Descending
        
        Write-Status "  Resource Types by total cost:"
        foreach ($type in $sortedTypes | Select-Object -First 10) {
            $percentage = if ($totalTypeCost -gt 0) { ($type.Value / $totalTypeCost) * 100 } else { 0 }
            Write-Status "    - $($type.Name): `$$([Math]::Round($type.Value, 2)) ($([Math]::Round($percentage, 2))%)"
        }
        
    } else {
        Write-Status "  No resource type-level cost data available"
    }
    
} catch {
    Write-Status "  Error analyzing resource type costs: $_"
}

# ===========================
# EXPORT RESULTS
# ===========================
Write-Status "Exporting cost data to CSV files..."

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force > $null
}

# Convert findings to PSObjects for export
$findingsArray = @()
foreach ($finding in $global:costFindings) {
    $findingsArray += [PSCustomObject]$finding
}

# Sort by cost (descending)
$findingsArray = $findingsArray | Sort-Object -Property Cost -Descending

# Export main cost data
$mainCsvPath = "$OutputPath\CostAssessment_DetailedCosts.csv"
$findingsArray | Export-Csv -Path $mainCsvPath -NoTypeInformation -Encoding UTF8

Write-Status "Detailed cost data exported to: $mainCsvPath"

# Generate summary reports by level
$summaryPath = "$OutputPath\CostAssessment_Summary.txt"
$summaryContent = @()

$summaryContent += "Azure Subscription Cost Assessment Report"
$summaryContent += "==========================================="
$summaryContent += "Assessment Date: $assessmentDate"
$summaryContent += "Subscription: $subscriptionName"
$summaryContent += "Analysis Period: Last $MonthsBack months"
$summaryContent += ""

# Subscription Level Summary
$subscriptionSummary = $findingsArray | Where-Object { $_.Level -eq "Subscription" }
if ($subscriptionSummary) {
    $totalSubCost = ($subscriptionSummary | Measure-Object -Property Cost -Sum).Sum
    $summaryContent += "SUBSCRIPTION LEVEL SUMMARY"
    $summaryContent += "=========================="
    $summaryContent += "Total Cost (Period): `$$([Math]::Round($totalSubCost, 2))"
    $summaryContent += "Average Monthly Cost: `$$([Math]::Round($totalSubCost / $subscriptionSummary.Count, 2))"
    $summaryContent += "Number of Months: $($subscriptionSummary.Count)"
    $summaryContent += ""
}

# Resource Group Level Summary
$rgSummary = $findingsArray | Where-Object { $_.Level -eq "Resource Group" }
if ($rgSummary) {
    $summaryContent += "RESOURCE GROUP LEVEL SUMMARY"
    $summaryContent += "============================="
    $rgGroups = $rgSummary | Group-Object -Property Category
    
    foreach ($rg in $rgGroups | Sort-Object -Property @{Expression={($_.Group | Measure-Object -Property Cost -Sum).Sum}} -Descending | Select-Object -First 10) {
        $rgTotalCost = ($rg.Group | Measure-Object -Property Cost -Sum).Sum
        $summaryContent += "  Resource Group: $($rg.Name) - Total: `$$([Math]::Round($rgTotalCost, 2))"
    }
    $summaryContent += ""
}

# Service Type Level Summary
$serviceSummary = $findingsArray | Where-Object { $_.Level -eq "Service Type" }
if ($serviceSummary) {
    $summaryContent += "SERVICE TYPE LEVEL SUMMARY"
    $summaryContent += "=========================="
    $serviceGroups = $serviceSummary | Group-Object -Property Category
    $totalServiceCost = ($serviceSummary | Measure-Object -Property Cost -Sum).Sum
    
    foreach ($svc in $serviceGroups | Sort-Object -Property @{Expression={($_.Group | Measure-Object -Property Cost -Sum).Sum}} -Descending | Select-Object -First 10) {
        $svcTotalCost = ($svc.Group | Measure-Object -Property Cost -Sum).Sum
        $percentage = if ($totalServiceCost -gt 0) { ($svcTotalCost / $totalServiceCost) * 100 } else { 0 }
        $summaryContent += "  Service: $($svc.Name) - Total: `$$([Math]::Round($svcTotalCost, 2)) ($([Math]::Round($percentage, 2))%)"
    }
    $summaryContent += ""
}

# Resource Type Level Summary
$typeSummary = $findingsArray | Where-Object { $_.Level -eq "Resource Type" }
if ($typeSummary) {
    $summaryContent += "RESOURCE TYPE LEVEL SUMMARY"
    $summaryContent += "============================"
    $typeGroups = $typeSummary | Group-Object -Property Category
    $totalTypeCost = ($typeSummary | Measure-Object -Property Cost -Sum).Sum
    
    foreach ($type in $typeGroups | Sort-Object -Property @{Expression={($_.Group | Measure-Object -Property Cost -Sum).Sum}} -Descending | Select-Object -First 10) {
        $typeTotalCost = ($type.Group | Measure-Object -Property Cost -Sum).Sum
        $percentage = if ($totalTypeCost -gt 0) { ($typeTotalCost / $totalTypeCost) * 100 } else { 0 }
        $summaryContent += "  Type: $($type.Name) - Total: `$$([Math]::Round($typeTotalCost, 2)) ($([Math]::Round($percentage, 2))%)"
    }
    $summaryContent += ""
}

# OVERALL STATISTICS
$summaryContent += "OVERALL STATISTICS"
$summaryContent += "=================="

if ($findingsArray.Count -gt 0) {
    $overallTotal = ($findingsArray | Measure-Object -Property Cost -Sum).Sum
    $summaryContent += "Total Cost (All Services, Period): `$$([Math]::Round($overallTotal, 2))"
} else {
    $summaryContent += "Total Cost (All Services, Period): `$0.00 (No cost data available)"
    $summaryContent += ""
    $summaryContent += "NOTE: Cost data may not be available if:"
    $summaryContent += "  - The service principal lacks Cost Management API permissions"
    $summaryContent += "  - Resources have not incurred charges yet"
    $summaryContent += "  - Cost data has not been processed by Azure billing system"
}

$rgCount = $findingsArray | Where-Object { $_.Level -eq 'Resource Group' } | Group-Object -Property Category | Measure-Object
$svcCount = $findingsArray | Where-Object { $_.Level -eq 'Service Type' } | Group-Object -Property Category | Measure-Object
$typeCount = $findingsArray | Where-Object { $_.Level -eq 'Resource Type' } | Group-Object -Property Category | Measure-Object

$summaryContent += "Unique Resource Groups Analyzed: $($rgCount.Count)"
$summaryContent += "Unique Services Found: $($svcCount.Count)"
$summaryContent += "Unique Resource Types Found: $($typeCount.Count)"
$summaryContent += "Records Analyzed: $($findingsArray.Count)"
$summaryContent += ""
$summaryContent += "RESOURCE INVENTORY"
$summaryContent += "=================="

# Count resources by type
try {
    $allResources = az resource list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($allResources -and $allResources.Count -gt 0) {
        $resourcesByType = $allResources | Group-Object -Property type
        $summaryContent += "Total Resources: $($allResources.Count)"
        $summaryContent += "Top Resource Types:"
        
        foreach ($rt in $resourcesByType | Sort-Object -Property Count -Descending | Select-Object -First 10) {
            $summaryContent += "  - $($rt.Name): $($rt.Count) instances"
        }
    }
} catch {
    $summaryContent += "Could not retrieve resource inventory"
}

# Export summary
$summaryContent | Out-File -FilePath $summaryPath -Encoding UTF8

Write-Host "
================================================================================
Azure Subscription Cost Assessment - Complete
================================================================================
Assessment Period: Last $MonthsBack months
Subscription: $subscriptionName (ID: $currentSubscription)

ANALYSIS LEVELS:
  1. Subscription Level - Total and monthly breakdown
  2. Resource Group Level - Top spending resource groups
  3. Service Type Level - Cost by Azure service category
  4. Resource Type Level - Cost by resource type

DELIVERABLES:
  1. Detailed Cost Report: $mainCsvPath
  2. Summary Report: $summaryPath

CSV COLUMNS:
  - AssessmentDate: When the analysis was performed
  - Level: Analysis level (Subscription/Resource Group/Service Type/Resource Type)
  - Category: Grouping category at that level
  - Name: Resource or service name
  - ServiceType: Azure service type
  - Cost: Cost amount (USD)
  - Currency: USD
  - TimeFrame: Monthly breakdown
  - Details: Additional context
  - CostTrend: Trend information
  - PercentageOfTotal: Percentage of total spend

IMPORTANT NOTES:
  - All costs are pre-tax and in USD
  - Data includes last $MonthsBack months
  - Resource Group and Service/Resource Type totals aggregated from monthly data
  - CSV contains raw monthly data for detailed analysis
  - Summary report provides executive overview

================================================================================
" -ForegroundColor Cyan

Write-Host "Cost assessment completed successfully!" -ForegroundColor Green
