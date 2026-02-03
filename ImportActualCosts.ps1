# Azure Cost Import Helper Script
# This script helps merge actual costs exported from Azure Portal into the cost assessment CSV

param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the cost assessment CSV file")]
    [string]$CostAssessmentCSV,
    
    [Parameter(Mandatory = $true, HelpMessage = "Path to the Azure Portal cost export CSV")]
    [string]$PortalCostExportCSV,
    
    [Parameter(Mandatory = $false, HelpMessage = "Output path for the merged CSV")]
    [string]$OutputCSV
)

if (-not (Test-Path $CostAssessmentCSV)) {
    Write-Host "Error: Cost assessment CSV not found: $CostAssessmentCSV" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $PortalCostExportCSV)) {
    Write-Host "Error: Portal cost export CSV not found: $PortalCostExportCSV" -ForegroundColor Red
    exit 1
}

if (-not $OutputCSV) {
    $OutputCSV = $CostAssessmentCSV -replace ".csv$", "_with_actual_costs.csv"
}

Write-Host "Importing actual costs from Azure Portal export..." -ForegroundColor Cyan

# Read both CSV files
$assessmentData = Import-Csv -Path $CostAssessmentCSV
$portalData = Import-Csv -Path $PortalCostExportCSV

Write-Host "Assessment CSV records: $($assessmentData.Count)" -ForegroundColor Gray
Write-Host "Portal export records: $($portalData.Count)" -ForegroundColor Gray

# Create a lookup table from portal data
# Common column names in Portal export: 'Resource ID', 'ResourceId', 'resource id', 'Cost'
$portalLookup = @{}
foreach ($item in $portalData) {
    # Try different column name variations
    $resourceId = $item.'Resource ID' ?? $item.'ResourceId' ?? $item.'resource id'
    $cost = [decimal]($item.'Cost' ?? $item.'PreTaxCost' ?? $item.'cost' ?? 0)
    
    if ($resourceId -and $cost -gt 0) {
        if (-not $portalLookup.ContainsKey($resourceId)) {
            $portalLookup[$resourceId] = $cost
        } else {
            $portalLookup[$resourceId] += $cost
        }
    }
}

Write-Host "Found $($portalLookup.Count) resources with costs in Portal export" -ForegroundColor Gray

# Update assessment data with actual costs
$updated = 0
foreach ($record in $assessmentData) {
    if ($portalLookup.ContainsKey($record.ResourceId)) {
        $record.ActualCost = $portalLookup[$record.ResourceId]
        $updated++
    }
}

# Export merged CSV
$assessmentData | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8 -Force

Write-Host "✓ Merged CSV exported to: $OutputCSV" -ForegroundColor Green
Write-Host "✓ Updated $updated records with actual costs" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "- Original file: $CostAssessmentCSV" -ForegroundColor Gray
Write-Host "- Portal export: $PortalCostExportCSV" -ForegroundColor Gray
Write-Host "- Output file: $OutputCSV" -ForegroundColor Gray
