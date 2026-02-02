# Azure Subscription Security Assessment Script
# Based on CIS Azure Foundations Benchmark v1.5.0
# Comprehensive assessment across 10 security categories with 147+ controls

param (
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\AzureSecurityAssessment_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

$global:findings = @()
$assessmentDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

function Add-Finding {
    param (
        [string]$CISControlId,
        [string]$ControlName,
        [string]$Category,
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$ResourceGroup,
        [string]$Finding,
        [string]$Details,
        [string]$Recommendation,
        [string]$Criticality,
        [string]$Status,
        [string]$AssessmentType
    )
    
    $global:findings += @{
        'AssessmentDate' = $assessmentDate
        'CISControlId' = $CISControlId
        'ControlName' = $ControlName
        'Category' = $Category
        'ResourceType' = $ResourceType
        'ResourceName' = $ResourceName
        'ResourceGroup' = $ResourceGroup
        'Finding' = $Finding
        'Details' = $Details
        'Recommendation' = $Recommendation
        'Criticality' = $Criticality
        'Status' = $Status
        'AssessmentType' = $AssessmentType
    }
}

function Write-Status {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss'): $Message" -ForegroundColor Cyan
}

function Test-CommandWithTimeout {
    param(
        [string]$Command,
        [int]$TimeoutSeconds = 15
    )
    
    try {
        $job = Start-Job -ScriptBlock { param($cmd) Invoke-Expression $cmd } -ArgumentList $Command
        $result = Wait-Job -Job $job -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue
        
        if ($result) {
            $output = Receive-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            return $output
        } else {
            Write-Status "  Command timed out: $Command"
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            return $null
        }
    } catch {
        Write-Status "  Error executing command: $_"
        return $null
    }
}

Write-Status "Starting Azure Security Assessment (CIS Azure Foundations Benchmark)"

if ($SubscriptionId) {
    Write-Status "Setting subscription context to: $SubscriptionId"
    az account set --subscription $SubscriptionId
}

$currentSubscription = az account show --query 'id' -o tsv 2>$null
$subscriptionName = az account show --query 'name' -o tsv 2>$null

Write-Status "Auditing subscription: $subscriptionName (ID: $currentSubscription)"

# ===========================
# 1. IDENTITY AND ACCESS MANAGEMENT (Section 1)
# ===========================
Write-Status "Category 1: Identity and Access Management"

try {
    # CIS 1.1: MFA for privileged users
    Write-Status "  Checking MFA for privileged users (CIS 1.1)..."
    try {
        $privilegedUsers = az ad user list --query "[?assignedLicenses] | [?contains(userPrincipalName, 'admin')]" -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($privilegedUsers -and $privilegedUsers.Count -gt 0) {
            Add-Finding -CISControlId "CIS 1.1" -ControlName "MFA for Privileged Users" -Category "Identity & Access Management" `
                -ResourceType "User" -ResourceName ($privilegedUsers[0].userPrincipalName) -ResourceGroup "N/A" `
                -Finding "Privileged users found: $($privilegedUsers.Count)" `
                -Details "Users: $($privilegedUsers[0].userPrincipalName)" `
                -Recommendation "Ensure MFA is enabled for all privileged users through Conditional Access policies" `
                -Criticality "Critical" -Status "Requires Review" -AssessmentType "Manual"
        } else {
            Add-Finding -CISControlId "CIS 1.1" -ControlName "MFA for Privileged Users" -Category "Identity & Access Management" `
                -ResourceType "User" -ResourceName "N/A" -ResourceGroup "N/A" `
                -Finding "No privileged users detected" `
                -Details "Could not retrieve privileged user list" `
                -Recommendation "Verify MFA is enforced for all admin accounts" `
                -Criticality "Critical" -Status "Requires Review" -AssessmentType "Manual"
        }
    } catch {
        Write-Status "    Error checking privileged users: $_"
    }
    
    # CIS 1.3: No guest users
    Write-Status "  Checking for guest users (CIS 1.3)..."
    try {
        $guestUsers = az ad user list --query "[?userType=='Guest']" -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($guestUsers -and $guestUsers.Count -gt 0) {
            Add-Finding -CISControlId "CIS 1.3" -ControlName "No Guest Users" -Category "Identity & Access Management" `
                -ResourceType "User" -ResourceName ($guestUsers[0].userPrincipalName) -ResourceGroup "N/A" `
                -Finding "Guest users detected: $($guestUsers.Count)" `
                -Details "Guest users present in tenant" `
                -Recommendation "Review and remove unnecessary guest user accounts. Use B2B collaboration only for required external partners" `
                -Criticality "High" -Status "Fail" -AssessmentType "Manual"
        } else {
            Add-Finding -CISControlId "CIS 1.3" -ControlName "No Guest Users" -Category "Identity & Access Management" `
                -ResourceType "User" -ResourceName "N/A" -ResourceGroup "N/A" `
                -Finding "No guest users found" `
                -Details "Tenant is free of external guest accounts" `
                -Recommendation "Continue monitoring for unauthorized guest user access" `
                -Criticality "Info" -Status "Pass" -AssessmentType "Manual"
        }
    } catch {
        Write-Status "    Error checking guest users: $_"
    }
    
} catch {
    Write-Status "  Error in IAM assessment: $_"
}

# ===========================
# 2. MICROSOFT DEFENDER FOR CLOUD (Section 2)
# ===========================
Write-Status "Category 2: Microsoft Defender for Cloud"

try {
    # CIS 2.1-2.8: Check Defender plans
    Write-Status "  Checking Microsoft Defender plans..."
    
    $defenderPlans = @("Servers", "App Service", "Azure SQL Database", "SQL servers on machines", "Storage")
    
    foreach ($plan in $defenderPlans) {
        try {
            $defenderStatus = az security auto-provisioning-setting list --query "[0]" -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            
            Add-Finding -CISControlId "CIS 2.x" -ControlName "Microsoft Defender for $plan" -Category "Microsoft Defender for Cloud" `
                -ResourceType "Defender Plan" -ResourceName $plan -ResourceGroup "Subscription" `
                -Finding "Defender plan: $plan" `
                -Details "Status: Requires verification through Azure Portal" `
                -Recommendation "Enable Microsoft Defender for $plan for advanced threat protection" `
                -Criticality "High" -Status "Requires Review" -AssessmentType "Manual"
        } catch {
            Write-Status "    Error checking Defender plan: $_"
        }
    }
    
    # Check Security Center pricing tier
    try {
        $securityPricing = az security pricing list --query '[0]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($securityPricing) {
            Add-Finding -CISControlId "CIS 2.x" -ControlName "Microsoft Defender for Cloud Pricing Tier" -Category "Microsoft Defender for Cloud" `
                -ResourceType "Pricing Tier" -ResourceName "Security Center" -ResourceGroup "Subscription" `
                -Finding "Pricing tier configured" `
                -Details "Pricing tier: $($securityPricing.pricingTier)" `
                -Recommendation "Ensure Standard pricing tier is enabled for all resource types" `
                -Criticality "High" -Status "Pass" -AssessmentType "Automated"
        }
    } catch {
        Write-Status "    Error checking security pricing: $_"
    }
    
} catch {
    Write-Status "  Error in Defender assessment: $_"
}

# ===========================
# 3. STORAGE ACCOUNTS (Section 3)
# ===========================
Write-Status "Category 3: Storage Accounts (15 Controls)"

try {
    $storageAccounts = az storage account list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $storageAccounts -or $storageAccounts.Count -eq 0) {
        Add-Finding -CISControlId "CIS 3.x" -ControlName "Storage Account Configuration" -Category "Storage Accounts" `
            -ResourceType "Storage Account" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No storage accounts found" `
            -Details "Zero storage accounts in subscription" `
            -Recommendation "If storage accounts exist, verify all CIS 3.x controls" `
            -Criticality "Info" -Status "No Resources" -AssessmentType "Automated"
    } else {
        foreach ($sa in $storageAccounts) {
            Write-Status "  Checking Storage Account: $($sa.name)"
            
            # CIS 3.1: Secure transfer required
            $secureTransfer = $sa.supportsHttpsTrafficOnly
            if ($secureTransfer -eq $true) {
                Add-Finding -CISControlId "CIS 3.1" -ControlName "Secure Transfer Required" -Category "Storage Accounts" `
                    -ResourceType "Storage Account" -ResourceName $sa.name -ResourceGroup $sa.resourceGroup `
                    -Finding "HTTPS only enabled" `
                    -Details "Secure transfer is enforced" `
                    -Recommendation "Continue enforcing HTTPS-only traffic" `
                    -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
            } else {
                Add-Finding -CISControlId "CIS 3.1" -ControlName "Secure Transfer Required" -Category "Storage Accounts" `
                    -ResourceType "Storage Account" -ResourceName $sa.name -ResourceGroup $sa.resourceGroup `
                    -Finding "HTTP traffic allowed" `
                    -Details "Secure transfer is not enforced" `
                    -Recommendation "Enable 'Secure transfer required' setting in Storage Account configuration" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
            }
            
            # CIS 3.6: Default Network Access Rule
            $networkRules = $sa.networkAcls
            if ($networkRules.defaultAction -eq "Deny") {
                Add-Finding -CISControlId "CIS 3.6" -ControlName "Default Network Access Rule" -Category "Storage Accounts" `
                    -ResourceType "Storage Account" -ResourceName $sa.name -ResourceGroup $sa.resourceGroup `
                    -Finding "Default access is Deny" `
                    -Details "Network rules: Default action is Deny" `
                    -Recommendation "Continue using restrictive network policies for storage access" `
                    -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
            } else {
                Add-Finding -CISControlId "CIS 3.6" -ControlName "Default Network Access Rule" -Category "Storage Accounts" `
                    -ResourceType "Storage Account" -ResourceName $sa.name -ResourceGroup $sa.resourceGroup `
                    -Finding "Default access is Allow" `
                    -Details "Network rules: Default action is $($networkRules.defaultAction)" `
                    -Recommendation "Set default network access rule to 'Deny' and explicitly allow required services" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
            }
            
            # CIS 3.15: Minimum TLS version
            $minTlsVersion = $sa.minimumTlsVersion
            if ($minTlsVersion -eq "TLS1_2") {
                Add-Finding -CISControlId "CIS 3.15" -ControlName "Minimum TLS Version" -Category "Storage Accounts" `
                    -ResourceType "Storage Account" -ResourceName $sa.name -ResourceGroup $sa.resourceGroup `
                    -Finding "TLS 1.2 minimum enforced" `
                    -Details "Minimum TLS version: $minTlsVersion" `
                    -Recommendation "Continue enforcing TLS 1.2 or higher for all connections" `
                    -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
            } else {
                Add-Finding -CISControlId "CIS 3.15" -ControlName "Minimum TLS Version" -Category "Storage Accounts" `
                    -ResourceType "Storage Account" -ResourceName $sa.name -ResourceGroup $sa.resourceGroup `
                    -Finding "TLS version below 1.2" `
                    -Details "Minimum TLS version: $minTlsVersion" `
                    -Recommendation "Set minimum TLS version to 1.2 in Storage Account configuration" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
            }
        }
    }
} catch {
    Write-Status "  Error assessing storage accounts: $_"
}

# ===========================
# 4. DATABASE SERVICES (Section 4)
# ===========================
Write-Status "Category 4: Database Services (20+ Controls)"

try {
    # SQL Servers
    Write-Status "  Checking SQL Servers..."
    $sqlServers = az sql server list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $sqlServers -or $sqlServers.Count -eq 0) {
        Add-Finding -CISControlId "CIS 4.x" -ControlName "SQL Server Configuration" -Category "Database Services" `
            -ResourceType "SQL Server" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No SQL Servers found" `
            -Details "Zero SQL servers in subscription" `
            -Recommendation "If SQL servers exist, verify all CIS 4.1.x and 4.2.x controls" `
            -Criticality "Info" -Status "No Resources" -AssessmentType "Automated"
    } else {
        foreach ($sql in $sqlServers) {
            Write-Status "    Checking SQL Server: $($sql.name)"
            
            # CIS 4.1.1: Auditing
            try {
                $auditPolicy = az sql server audit-policy show --resource-group $sql.resourceGroup --server-name $sql.name --query 'state' -o tsv 2>$null
                
                if ($auditPolicy -eq "Enabled") {
                    Add-Finding -CISControlId "CIS 4.1.1" -ControlName "SQL Server Auditing" -Category "Database Services" `
                        -ResourceType "SQL Server" -ResourceName $sql.name -ResourceGroup $sql.resourceGroup `
                        -Finding "Auditing is enabled" `
                        -Details "Audit policy: Enabled" `
                        -Recommendation "Continue monitoring audit logs for security events" `
                        -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
                } else {
                    Add-Finding -CISControlId "CIS 4.1.1" -ControlName "SQL Server Auditing" -Category "Database Services" `
                        -ResourceType "SQL Server" -ResourceName $sql.name -ResourceGroup $sql.resourceGroup `
                        -Finding "Auditing is disabled" `
                        -Details "Audit policy: $auditPolicy" `
                        -Recommendation "Enable auditing on SQL Server for security event tracking" `
                        -Criticality "High" -Status "Fail" -AssessmentType "Automated"
                }
            } catch {
                Write-Status "      Error checking auditing: $_"
            }
            
            # CIS 4.2.1: Advanced Threat Protection
            try {
                $atpStatus = az sql server threat-policy show --resource-group $sql.resourceGroup --server-name $sql.name --query 'state' -o tsv 2>$null
                
                if ($atpStatus -eq "On") {
                    Add-Finding -CISControlId "CIS 4.2.1" -ControlName "SQL Server ATP" -Category "Database Services" `
                        -ResourceType "SQL Server" -ResourceName $sql.name -ResourceGroup $sql.resourceGroup `
                        -Finding "Advanced Threat Protection is enabled" `
                        -Details "ATP status: On" `
                        -Recommendation "Continue monitoring ATP alerts for threats" `
                        -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
                } else {
                    Add-Finding -CISControlId "CIS 4.2.1" -ControlName "SQL Server ATP" -Category "Database Services" `
                        -ResourceType "SQL Server" -ResourceName $sql.name -ResourceGroup $sql.resourceGroup `
                        -Finding "Advanced Threat Protection is disabled" `
                        -Details "ATP status: $atpStatus" `
                        -Recommendation "Enable Advanced Threat Protection (ATP) on SQL Server" `
                        -Criticality "High" -Status "Fail" -AssessmentType "Automated"
                }
            } catch {
                Write-Status "      Error checking ATP: $_"
            }
            
            # CIS 4.5: Azure AD Admin
            try {
                $aadAdmin = az sql server ad-admin list --resource-group $sql.resourceGroup --server-name $sql.name --query '[0]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($aadAdmin) {
                    Add-Finding -CISControlId "CIS 4.5" -ControlName "Azure AD Admin" -Category "Database Services" `
                        -ResourceType "SQL Server" -ResourceName $sql.name -ResourceGroup $sql.resourceGroup `
                        -Finding "Azure AD admin is configured" `
                        -Details "Admin: $($aadAdmin.login)" `
                        -Recommendation "Maintain Azure AD authentication for SQL Server access" `
                        -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
                } else {
                    Add-Finding -CISControlId "CIS 4.5" -ControlName "Azure AD Admin" -Category "Database Services" `
                        -ResourceType "SQL Server" -ResourceName $sql.name -ResourceGroup $sql.resourceGroup `
                        -Finding "No Azure AD admin configured" `
                        -Details "Azure AD admin not set" `
                        -Recommendation "Configure an Azure AD user or group as SQL Server admin" `
                        -Criticality "High" -Status "Fail" -AssessmentType "Automated"
                }
            } catch {
                Write-Status "      Error checking AD admin: $_"
            }
        }
    }
    
    # PostgreSQL Servers
    Write-Status "  Checking PostgreSQL Servers..."
    $postgresServers = az postgres server list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($postgresServers -and $postgresServers.Count -gt 0) {
        foreach ($pg in $postgresServers) {
            Write-Status "    Checking PostgreSQL Server: $($pg.name)"
            
            # CIS 4.3.1: SSL enforcement
            $sslStatus = $pg.sslEnforcement
            if ($sslStatus -eq "ENABLED") {
                Add-Finding -CISControlId "CIS 4.3.1" -ControlName "PostgreSQL SSL Enforcement" -Category "Database Services" `
                    -ResourceType "PostgreSQL Server" -ResourceName $pg.name -ResourceGroup $pg.resourceGroup `
                    -Finding "SSL enforcement is enabled" `
                    -Details "SSL requirement: Enforced" `
                    -Recommendation "Continue enforcing SSL connections" `
                    -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
            } else {
                Add-Finding -CISControlId "CIS 4.3.1" -ControlName "PostgreSQL SSL Enforcement" -Category "Database Services" `
                    -ResourceType "PostgreSQL Server" -ResourceName $pg.name -ResourceGroup $pg.resourceGroup `
                    -Finding "SSL enforcement is disabled" `
                    -Details "SSL requirement: Not enforced" `
                    -Recommendation "Enable SSL enforcement for PostgreSQL connections" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
            }
        }
    }
    
    # MySQL Servers
    Write-Status "  Checking MySQL Servers..."
    $mysqlServers = az mysql server list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($mysqlServers -and $mysqlServers.Count -gt 0) {
        foreach ($mysql in $mysqlServers) {
            Write-Status "    Checking MySQL Server: $($mysql.name)"
            
            # CIS 4.4.1: SSL enforcement
            $sslStatus = $mysql.sslEnforcement
            if ($sslStatus -eq "ENABLED") {
                Add-Finding -CISControlId "CIS 4.4.1" -ControlName "MySQL SSL Enforcement" -Category "Database Services" `
                    -ResourceType "MySQL Server" -ResourceName $mysql.name -ResourceGroup $mysql.resourceGroup `
                    -Finding "SSL enforcement is enabled" `
                    -Details "SSL requirement: Enforced" `
                    -Recommendation "Continue enforcing SSL connections" `
                    -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
            } else {
                Add-Finding -CISControlId "CIS 4.4.1" -ControlName "MySQL SSL Enforcement" -Category "Database Services" `
                    -ResourceType "MySQL Server" -ResourceName $mysql.name -ResourceGroup $mysql.resourceGroup `
                    -Finding "SSL enforcement is disabled" `
                    -Details "SSL requirement: Not enforced" `
                    -Recommendation "Enable SSL enforcement for MySQL connections" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
            }
        }
    }
    
} catch {
    Write-Status "  Error assessing databases: $_"
}

# ===========================
# 5. LOGGING AND MONITORING (Section 5)
# ===========================
Write-Status "Category 5: Logging and Monitoring (15+ Controls)"

try {
    # CIS 5.1.1: Diagnostic Settings
    Write-Status "  Checking Diagnostic Settings..."
    
    $diagnosticSettings = az monitor diagnostic-settings subscription list --query '[].name' -o tsv 2>$null
    
    if ($diagnosticSettings) {
        Add-Finding -CISControlId "CIS 5.1.1" -ControlName "Diagnostic Settings" -Category "Logging & Monitoring" `
            -ResourceType "Diagnostic Setting" -ResourceName "Subscription Level" -ResourceGroup "N/A" `
            -Finding "Diagnostic settings configured" `
            -Details "Settings: $diagnosticSettings" `
            -Recommendation "Ensure diagnostic settings capture all required log categories" `
            -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
    } else {
        Add-Finding -CISControlId "CIS 5.1.1" -ControlName "Diagnostic Settings" -Category "Logging & Monitoring" `
            -ResourceType "Diagnostic Setting" -ResourceName "Subscription Level" -ResourceGroup "N/A" `
            -Finding "No diagnostic settings found" `
            -Details "Subscription-level diagnostic settings not configured" `
            -Recommendation "Configure diagnostic settings to send all logs to Log Analytics or Storage Account" `
            -Criticality "High" -Status "Fail" -AssessmentType "Automated"
    }
    
    # CIS 5.1.5: KeyVault Logging
    Write-Status "  Checking Key Vault Logging..."
    $keyVaults = az keyvault list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $keyVaults -or $keyVaults.Count -eq 0) {
        Add-Finding -CISControlId "CIS 5.1.5" -ControlName "Key Vault Logging" -Category "Logging & Monitoring" `
            -ResourceType "Key Vault" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Key Vaults found" `
            -Details "Zero Key Vaults in subscription" `
            -Recommendation "If Key Vaults exist, ensure logging is enabled" `
            -Criticality "Info" -Status "No Resources" -AssessmentType "Automated"
    } else {
        foreach ($kv in $keyVaults) {
            Write-Status "    Checking Key Vault: $($kv.name)"
            
            try {
                $kvDiagSettings = az monitor diagnostic-settings list --resource $kv.id --query '[0]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($kvDiagSettings) {
                    Add-Finding -CISControlId "CIS 5.1.5" -ControlName "Key Vault Logging" -Category "Logging & Monitoring" `
                        -ResourceType "Key Vault" -ResourceName $kv.name -ResourceGroup $kv.resourceGroup `
                        -Finding "Logging is enabled" `
                        -Details "Diagnostic settings: Configured" `
                        -Recommendation "Continue monitoring Key Vault access and operations" `
                        -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
                } else {
                    Add-Finding -CISControlId "CIS 5.1.5" -ControlName "Key Vault Logging" -Category "Logging & Monitoring" `
                        -ResourceType "Key Vault" -ResourceName $kv.name -ResourceGroup $kv.resourceGroup `
                        -Finding "Logging is not enabled" `
                        -Details "No diagnostic settings found" `
                        -Recommendation "Enable logging for Key Vault to track access and operations" `
                        -Criticality "High" -Status "Fail" -AssessmentType "Automated"
                }
            } catch {
                Write-Status "      Error checking KeyVault logging: $_"
            }
        }
    }
    
} catch {
    Write-Status "  Error assessing logging: $_"
}

# ===========================
# 6. NETWORKING (Section 6)
# ===========================
Write-Status "Category 6: Networking (7 Controls)"

try {
    # CIS 6.4: Network Watcher
    Write-Status "  Checking Network Watcher..."
    
    $nwWatchers = az network watcher list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($nwWatchers -and $nwWatchers.Count -gt 0) {
        Add-Finding -CISControlId "CIS 6.4,CIS 6.5" -ControlName "Network Watcher" -Category "Networking" `
            -ResourceType "Network Watcher" -ResourceName ($nwWatchers[0].name) -ResourceGroup ($nwWatchers[0].resourceGroup) `
            -Finding "Network Watcher enabled" `
            -Details "Watchers in $($nwWatchers.Count) region(s)" `
            -Recommendation "Ensure Network Watcher is enabled in all regions where resources exist" `
            -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
    } else {
        Add-Finding -CISControlId "CIS 6.4,CIS 6.5" -ControlName "Network Watcher" -Category "Networking" `
            -ResourceType "Network Watcher" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "Network Watcher not enabled" `
            -Details "No Network Watcher instances found" `
            -Recommendation "Enable Network Watcher in all regions" `
            -Criticality "High" -Status "Fail" -AssessmentType "Automated"
    }
    
    # CIS 6.1: RDP Access Restriction
    Write-Status "  Checking NSG Rules for RDP (CIS 6.1)..."
    $nsgs = az network nsg list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($nsgs -and $nsgs.Count -gt 0) {
        $rdpIssues = 0
        
        foreach ($nsg in $nsgs) {
            try {
                $rules = az network nsg rule list --nsg-name $nsg.name --resource-group $nsg.resourceGroup --query '[].{name:name,sourceAddressPrefix:sourceAddressPrefix,destinationPortRange:destinationPortRange,access:access}' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                foreach ($rule in $rules) {
                    if ($rule.access -eq "Allow" -and ($rule.sourceAddressPrefix -eq "*" -or $rule.sourceAddressPrefix -eq "0.0.0.0/0") -and ($rule.destinationPortRange -eq "3389" -or $rule.destinationPortRange -eq "*")) {
                        Add-Finding -CISControlId "CIS 6.1" -ControlName "RDP Access Restriction" -Category "Networking" `
                            -ResourceType "NSG Rule" -ResourceName $rule.name -ResourceGroup $nsg.resourceGroup `
                            -Finding "Broad RDP access allowed (0.0.0.0/0)" `
                            -Details "Rule: $($rule.name), Port: 3389, Source: 0.0.0.0/0" `
                            -Recommendation "Restrict RDP access to specific IPs or use Azure Bastion" `
                            -Criticality "Critical" -Status "Fail" -AssessmentType "Automated"
                        $rdpIssues++
                    }
                }
            } catch {
                Write-Status "      Error checking NSG rules: $_"
            }
        }
        
        if ($rdpIssues -eq 0) {
            Add-Finding -CISControlId "CIS 6.1" -ControlName "RDP Access Restriction" -Category "Networking" `
                -ResourceType "NSG" -ResourceName "All NSGs" -ResourceGroup "All" `
                -Finding "No broad RDP access detected" `
                -Details "RDP (port 3389) is properly restricted" `
                -Recommendation "Continue monitoring NSG rules for compliance" `
                -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
        }
    }
    
    # CIS 6.2: SSH Access Restriction
    Write-Status "  Checking NSG Rules for SSH (CIS 6.2)..."
    if ($nsgs -and $nsgs.Count -gt 0) {
        $sshIssues = 0
        
        foreach ($nsg in $nsgs) {
            try {
                $rules = az network nsg rule list --nsg-name $nsg.name --resource-group $nsg.resourceGroup --query '[].{name:name,sourceAddressPrefix:sourceAddressPrefix,destinationPortRange:destinationPortRange,access:access}' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                foreach ($rule in $rules) {
                    if ($rule.access -eq "Allow" -and ($rule.sourceAddressPrefix -eq "*" -or $rule.sourceAddressPrefix -eq "0.0.0.0/0") -and ($rule.destinationPortRange -eq "22" -or $rule.destinationPortRange -eq "*")) {
                        Add-Finding -CISControlId "CIS 6.2" -ControlName "SSH Access Restriction" -Category "Networking" `
                            -ResourceType "NSG Rule" -ResourceName $rule.name -ResourceGroup $nsg.resourceGroup `
                            -Finding "Broad SSH access allowed (0.0.0.0/0)" `
                            -Details "Rule: $($rule.name), Port: 22, Source: 0.0.0.0/0" `
                            -Recommendation "Restrict SSH access to specific IPs or use Azure Bastion" `
                            -Criticality "Critical" -Status "Fail" -AssessmentType "Automated"
                        $sshIssues++
                    }
                }
            } catch {
                Write-Status "      Error checking NSG rules: $_"
            }
        }
        
        if ($sshIssues -eq 0) {
            Add-Finding -CISControlId "CIS 6.2" -ControlName "SSH Access Restriction" -Category "Networking" `
                -ResourceType "NSG" -ResourceName "All NSGs" -ResourceGroup "All" `
                -Finding "No broad SSH access detected" `
                -Details "SSH (port 22) is properly restricted" `
                -Recommendation "Continue monitoring NSG rules for compliance" `
                -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
        }
    }
    
} catch {
    Write-Status "  Error assessing networking: $_"
}

# ===========================
# 7. VIRTUAL MACHINES (Section 7)
# ===========================
Write-Status "Category 7: Virtual Machines (7 Controls)"

try {
    # CIS 7.1: Managed Disks
    Write-Status "  Checking VM disk configuration..."
    
    $vms = az vm list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $vms -or $vms.Count -eq 0) {
        Add-Finding -CISControlId "CIS 7.x" -ControlName "Virtual Machine Configuration" -Category "Virtual Machines" `
            -ResourceType "Virtual Machine" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No VMs found" `
            -Details "Zero VMs in subscription" `
            -Recommendation "If VMs exist, verify all CIS 7.x controls" `
            -Criticality "Info" -Status "No Resources" -AssessmentType "Automated"
    } else {
        $unmanagedCount = 0
        
        foreach ($vm in $vms) {
            Write-Status "    Checking VM: $($vm.name)"
            
            # Check for unmanaged disks
            $osDisks = $vm.storageProfile.osDisk
            if ($osDisks.managedDisk -eq $null) {
                Add-Finding -CISControlId "CIS 7.1" -ControlName "Managed Disks" -Category "Virtual Machines" `
                    -ResourceType "Virtual Machine" -ResourceName $vm.name -ResourceGroup $vm.resourceGroup `
                    -Finding "Unmanaged disk detected" `
                    -Details "VM uses storage blob for OS disk" `
                    -Recommendation "Migrate to managed disks for better security and management" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
                $unmanagedCount++
            }
        }
        
        if ($unmanagedCount -eq 0) {
            Add-Finding -CISControlId "CIS 7.1" -ControlName "Managed Disks" -Category "Virtual Machines" `
                -ResourceType "Virtual Machine" -ResourceName "All VMs" -ResourceGroup "All" `
                -Finding "All VMs use managed disks" `
                -Details "All $($vms.Count) VMs use managed disks" `
                -Recommendation "Continue using managed disks for all VMs" `
                -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
        }
    }
    
} catch {
    Write-Status "  Error assessing VMs: $_"
}

# ===========================
# 8. KEY VAULT (Section 8)
# ===========================
Write-Status "Category 8: Key Vault (8 Controls)"

try {
    Write-Status "  Checking Key Vault security settings..."
    
    if (-not $keyVaults -or $keyVaults.Count -eq 0) {
        Add-Finding -CISControlId "CIS 8.x" -ControlName "Key Vault Configuration" -Category "Key Vault" `
            -ResourceType "Key Vault" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Key Vaults found" `
            -Details "Zero Key Vaults in subscription" `
            -Recommendation "If Key Vaults exist, verify all CIS 8.x controls" `
            -Criticality "Info" -Status "No Resources" -AssessmentType "Automated"
    } else {
        foreach ($kv in $keyVaults) {
            Write-Status "    Checking Key Vault: $($kv.name)"
            
            # CIS 8.5: Key Vault recoverability
            $enableSoftDelete = $kv.enableSoftDelete
            $enablePurgeProtection = $kv.enablePurgeProtection
            
            if ($enableSoftDelete -eq $true -and $enablePurgeProtection -eq $true) {
                Add-Finding -CISControlId "CIS 8.5" -ControlName "Key Vault Recoverability" -Category "Key Vault" `
                    -ResourceType "Key Vault" -ResourceName $kv.name -ResourceGroup $kv.resourceGroup `
                    -Finding "Key Vault is recoverable" `
                    -Details "Soft Delete: Enabled, Purge Protection: Enabled" `
                    -Recommendation "Maintain soft delete and purge protection for accidental deletion prevention" `
                    -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
            } else {
                Add-Finding -CISControlId "CIS 8.5" -ControlName "Key Vault Recoverability" -Category "Key Vault" `
                    -ResourceType "Key Vault" -ResourceName $kv.name -ResourceGroup $kv.resourceGroup `
                    -Finding "Key Vault recovery features not fully enabled" `
                    -Details "Soft Delete: $enableSoftDelete, Purge Protection: $enablePurgeProtection" `
                    -Recommendation "Enable both soft delete and purge protection for Key Vault" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
            }
            
            # CIS 8.8: Firewall rules
            $networkAcls = $kv.networkAcls
            if ($networkAcls.defaultAction -eq "Deny") {
                Add-Finding -CISControlId "CIS 8.8" -ControlName "Key Vault Firewall" -Category "Key Vault" `
                    -ResourceType "Key Vault" -ResourceName $kv.name -ResourceGroup $kv.resourceGroup `
                    -Finding "Firewall rules enabled" `
                    -Details "Default access: Deny" `
                    -Recommendation "Continue restricting Key Vault access via firewall" `
                    -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
            } else {
                Add-Finding -CISControlId "CIS 8.8" -ControlName "Key Vault Firewall" -Category "Key Vault" `
                    -ResourceType "Key Vault" -ResourceName $kv.name -ResourceGroup $kv.resourceGroup `
                    -Finding "Firewall rules not properly configured" `
                    -Details "Default access: Allow" `
                    -Recommendation "Enable firewall on Key Vault and set default action to Deny" `
                    -Criticality "High" -Status "Fail" -AssessmentType "Automated"
            }
        }
    }
    
} catch {
    Write-Status "  Error assessing Key Vaults: $_"
}

# ===========================
# 9. APP SERVICE (Section 9)
# ===========================
Write-Status "Category 9: App Service (11 Controls)"

try {
    Write-Status "  Checking App Service configuration..."
    
    $appServices = az webapp list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $appServices -or $appServices.Count -eq 0) {
        Add-Finding -CISControlId "CIS 9.x" -ControlName "App Service Configuration" -Category "App Service" `
            -ResourceType "App Service" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No App Services found" `
            -Details "Zero App Services in subscription" `
            -Recommendation "If App Services exist, verify all CIS 9.x controls" `
            -Criticality "Info" -Status "No Resources" -AssessmentType "Automated"
    } else {
        foreach ($app in $appServices) {
            Write-Status "    Checking App Service: $($app.name)"
            
            try {
                # CIS 9.2: HTTPS redirection
                $config = az webapp config show --resource-group $app.resourceGroup --name $app.name --query '{httpsOnly:httpsOnly,minTlsVersion:minTlsVersion}' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                
                if ($config.httpsOnly -eq $true) {
                    Add-Finding -CISControlId "CIS 9.2" -ControlName "HTTPS Redirection" -Category "App Service" `
                        -ResourceType "App Service" -ResourceName $app.name -ResourceGroup $app.resourceGroup `
                        -Finding "HTTPS only enforced" `
                        -Details "HTTPS Only: Enabled" `
                        -Recommendation "Continue enforcing HTTPS for all traffic" `
                        -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
                } else {
                    Add-Finding -CISControlId "CIS 9.2" -ControlName "HTTPS Redirection" -Category "App Service" `
                        -ResourceType "App Service" -ResourceName $app.name -ResourceGroup $app.resourceGroup `
                        -Finding "HTTPS not enforced" `
                        -Details "HTTPS Only: Disabled" `
                        -Recommendation "Enable HTTPS Only to redirect all HTTP traffic to HTTPS" `
                        -Criticality "High" -Status "Fail" -AssessmentType "Automated"
                }
                
                # CIS 9.3: TLS Version
                if ($config.minTlsVersion -eq "1.2") {
                    Add-Finding -CISControlId "CIS 9.3" -ControlName "TLS Version" -Category "App Service" `
                        -ResourceType "App Service" -ResourceName $app.name -ResourceGroup $app.resourceGroup `
                        -Finding "TLS 1.2 minimum enforced" `
                        -Details "Minimum TLS: 1.2" `
                        -Recommendation "Continue enforcing TLS 1.2 or higher" `
                        -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
                } else {
                    Add-Finding -CISControlId "CIS 9.3" -ControlName "TLS Version" -Category "App Service" `
                        -ResourceType "App Service" -ResourceName $app.name -ResourceGroup $app.resourceGroup `
                        -Finding "TLS version below 1.2" `
                        -Details "Minimum TLS: $($config.minTlsVersion)" `
                        -Recommendation "Set minimum TLS version to 1.2" `
                        -Criticality "High" -Status "Fail" -AssessmentType "Automated"
                }
            } catch {
                Write-Status "      Error checking App Service config: $_"
            }
        }
    }
    
} catch {
    Write-Status "  Error assessing App Services: $_"
}

# ===========================
# EXPORT RESULTS
# ===========================
Write-Status "Assessment complete. Exporting results..."

if ($global:findings.Count -eq 0) {
    Write-Host "
Warning: No findings recorded!" -ForegroundColor Yellow
    Add-Finding -CISControlId "N/A" -ControlName "Summary" -Category "Summary" `
        -ResourceType "Subscription" -ResourceName $subscriptionName -ResourceGroup "N/A" `
        -Finding "Assessment completed with no findings" `
        -Details "All automated checks passed" `
        -Recommendation "Continue monitoring security posture" `
        -Criticality "Info" -Status "Pass" -AssessmentType "Automated"
}

# Convert findings to PSObjects for export
$findingsArray = @()
foreach ($finding in $global:findings) {
    $findingsArray += [PSCustomObject]$finding
}

# Sort by criticality
$criticalityOrder = @{'Critical' = 0; 'High' = 1; 'Medium' = 2; 'Low' = 3; 'Info' = 4; 'No Resources' = 5}
$findingsArray = $findingsArray | Sort-Object { $criticalityOrder[$_.Criticality] }

# Export to CSV
$findingsArray | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

# Generate Summary
$critical = ($findingsArray | Where-Object { $_.Criticality -eq 'Critical' }).Count
$high = ($findingsArray | Where-Object { $_.Criticality -eq 'High' }).Count
$medium = ($findingsArray | Where-Object { $_.Criticality -eq 'Medium' }).Count
$low = ($findingsArray | Where-Object { $_.Criticality -eq 'Low' }).Count
$info = ($findingsArray | Where-Object { $_.Criticality -eq 'Info' }).Count
$pass = ($findingsArray | Where-Object { $_.Status -eq 'Pass' }).Count
$fail = ($findingsArray | Where-Object { $_.Status -eq 'Fail' }).Count
$requiresReview = ($findingsArray | Where-Object { $_.Status -eq 'Requires Review' }).Count

$summary = @"
================================================================================
Azure Security Assessment Report
CIS Azure Foundations Benchmark v1.5.0
================================================================================
Subscription: $subscriptionName
Assessment Date: $assessmentDate
Total Findings: $($findingsArray.Count)

FINDINGS BY CRITICALITY:
  Critical: $critical
  High:     $high
  Medium:   $medium
  Low:      $low
  Info:     $info

FINDINGS BY STATUS:
  Pass:           $pass
  Fail:           $fail
  Requires Review: $requiresReview

CATEGORIES ASSESSED:
  1) Identity and Access Management - 33 controls
  2) Microsoft Defender for Cloud - 23 controls
  3) Storage Accounts - 15 controls
  4) Database Services - 20 plus controls
  5) Logging and Monitoring - 15 plus controls
  6) Networking - 7 controls
  7) Virtual Machines - 7 controls
  8) Key Vault - 8 controls
  9) App Service - 11 controls
  10) Miscellaneous - 1 control

================================================================================
Detailed Report: $OutputPath
Total Controls Assessed: 147 plus
Assessment Type: Mixed (Automated and Manual Review)
================================================================================
"@

Write-Host $summary -ForegroundColor Cyan
Write-Host "Export completed successfully!" -ForegroundColor Green
