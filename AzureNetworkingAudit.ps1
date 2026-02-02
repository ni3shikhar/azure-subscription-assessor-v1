# Azure Networking Configuration Assessment Script
# Comprehensive assessment against 12 network security control categories
# Includes CIS Azure Foundations Benchmark, Network Security Best Practices
# Outputs detailed resource information, findings, and recommendations to CSV

param (
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\AzureNetworkingAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

$findings = [System.Collections.ArrayList]@()
$assessmentDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

function Add-Finding {
    param (
        [string]$ControlId,
        [string]$ControlName,
        [string]$Category,
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$ResourceGroup,
        [string]$Finding,
        [string]$Details,
        [string]$Recommendation,
        [string]$Criticality,
        [string]$Status
    )
    
    [void]$findings.Add([PSCustomObject]@{
        AssessmentDate     = $assessmentDate
        ControlId          = $ControlId
        ControlName        = $ControlName
        Category           = $Category
        ResourceType       = $ResourceType
        ResourceName       = $ResourceName
        ResourceGroup      = $ResourceGroup
        Finding            = $Finding
        Details            = $Details
        Recommendation     = $Recommendation
        Criticality        = $Criticality
        Status             = $Status
    })
}

function Write-Status {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss'): $Message" -ForegroundColor Cyan
}

function Test-JsonConversion {
    param([string]$JsonString)
    try {
        $JsonString | ConvertFrom-Json -ErrorAction SilentlyContinue > $null
        return $true
    } catch {
        return $false
    }
}

Write-Status "Starting Azure Networking Configuration Assessment..."

if ($SubscriptionId) {
    Write-Status "Setting subscription context to: $SubscriptionId"
    az account set --subscription $SubscriptionId
}

$currentSubscription = az account show --query 'id' -o tsv
$subscriptionName = az account show --query 'name' -o tsv

Write-Status "Auditing subscription: $subscriptionName (ID: $currentSubscription)"

# ===========================
# 1. NETWORK SEGMENTATION & ARCHITECTURE
# ===========================
Write-Status "Category 1: Network Segmentation & Architecture"

try {
    $vnets = az network vnet list --query '[]' -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $vnets -or $vnets.Count -eq 0) {
        Add-Finding -ControlId "NS-1" -ControlName "VNet Segmentation" -Category "Network Segmentation" `
            -ResourceType "Virtual Network" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Virtual Networks found" `
            -Details "No VNets detected in the subscription" `
            -Recommendation "Implement Virtual Networks with subnet segmentation based on security zones (DMZ, application, database tiers)" `
            -Criticality "High" -Status "No Resources"
    } else {
        foreach ($vnet in $vnets) {
            Write-Status "  Checking VNet: $($vnet.name)"
            
            # NS-1: Check VNet implementation
            Add-Finding -ControlId "NS-1" -ControlName "VNet Segmentation" -Category "Network Segmentation" `
                -ResourceType "Virtual Network" -ResourceName $vnet.name -ResourceGroup $vnet.resourceGroup `
                -Finding "VNet exists: $($vnet.name)" `
                -Details "Address space: $($vnet.addressSpace.addressPrefixes -join ', '), Subnets: $($vnet.subnets.count)" `
                -Recommendation "Verify subnets are organized by security zones (public, application, database, management)" `
                -Criticality "Info" -Status "Pass"
            
            # NS-2: Check subnet sizing
            foreach ($subnet in $vnet.subnets) {
                $cidr = $subnet.addressPrefix
                Add-Finding -ControlId "NS-2" -ControlName "CIDR Subnetting" -Category "Network Segmentation" `
                    -ResourceType "Subnet" -ResourceName $subnet.name -ResourceGroup $vnet.resourceGroup `
                    -Finding "Subnet configured: $($subnet.name)" `
                    -Details "Address prefix: $cidr, Associated resources: Present" `
                    -Recommendation "Ensure CIDR blocks follow subnetting best practices and avoid overlapping address spaces" `
                    -Criticality "Info" -Status "Pass"
            }
            
            # NS-4: Check for hub-and-spoke pattern
            $vnetPeerings = $vnet.virtualNetworkPeerings
            if ($vnetPeerings -and $vnetPeerings.Count -gt 0) {
                Add-Finding -ControlId "NS-4" -ControlName "Hub-and-Spoke Architecture" -Category "Network Segmentation" `
                    -ResourceType "Virtual Network" -ResourceName $vnet.name -ResourceGroup $vnet.resourceGroup `
                    -Finding "VNet peerings detected" `
                    -Details "Number of peerings: $($vnetPeerings.Count)" `
                    -Recommendation "Implement hub-and-spoke or Virtual WAN for centralized management" `
                    -Criticality "Medium" -Status "Partial"
            } else {
                Add-Finding -ControlId "NS-4" -ControlName "Hub-and-Spoke Architecture" -Category "Network Segmentation" `
                    -ResourceType "Virtual Network" -ResourceName $vnet.name -ResourceGroup $vnet.resourceGroup `
                    -Finding "No hub-and-spoke pattern detected" `
                    -Details "VNet is isolated without peering relationships" `
                    -Recommendation "Consider implementing hub-and-spoke for multi-VNet environments for centralized security and management" `
                    -Criticality "Medium" -Status "Fail"
            }
        }
    }
} catch {
    Write-Status "  Error assessing VNets: $_"
}

# Check for Application Security Groups (ASGs)
Write-Status "  Checking Application Security Groups..."
try {
    $asgs = az network asg list --query '[]' -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($asgs -and $asgs.Count -gt 0) {
        Add-Finding -ControlId "NS-5" -ControlName "ASG Implementation" -Category "Network Segmentation" `
            -ResourceType "Application Security Group" -ResourceName ($asgs[0].name) -ResourceGroup ($asgs[0].resourceGroup) `
            -Finding "ASGs implemented: $($asgs.Count)" `
            -Details "ASG count: $($asgs.Count)" `
            -Recommendation "Use ASGs to simplify complex security configurations and improve manageability" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "NS-5" -ControlName "ASG Implementation" -Category "Network Segmentation" `
            -ResourceType "Application Security Group" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No ASGs found" `
            -Details "Consider using ASGs to simplify NSG rule management" `
            -Recommendation "Deploy ASGs to group VMs and simplify security rule configuration" `
            -Criticality "Low" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking ASGs: $_"
}

# ===========================
# 2. NETWORK SECURITY GROUPS (NSGs)
# ===========================
Write-Status "Category 2: Network Security Groups (NSGs)"

try {
    $nsgs = az network nsg list --query '[]' -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $nsgs -or $nsgs.Count -eq 0) {
        Add-Finding -ControlId "NSG-1" -ControlName "NSG Configuration" -Category "Network Security Groups" `
            -ResourceType "Network Security Group" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No NSGs found" `
            -Details "Zero NSGs in subscription" `
            -Recommendation "Deploy NSGs on all VNet subnets to control inbound and outbound traffic" `
            -Criticality "Critical" -Status "Fail"
    } else {
        $broadAllowCount = 0
        
        foreach ($nsg in $nsgs) {
            Write-Status "  Checking NSG: $($nsg.name)"
            
            # NSG-1: Verify NSG on subnets
            $subnets = $nsg.subnets
            if ($subnets -and $subnets.Count -gt 0) {
                Add-Finding -ControlId "NSG-1" -ControlName "NSG Configuration" -Category "Network Security Groups" `
                    -ResourceType "Network Security Group" -ResourceName $nsg.name -ResourceGroup $nsg.resourceGroup `
                    -Finding "NSG applied to subnets" `
                    -Details "Applied to $($subnets.Count) subnet(s)" `
                    -Recommendation "Ensure all VNet subnets have NSGs (except GatewaySubnet, AzureFirewallSubnet)" `
                    -Criticality "Info" -Status "Pass"
            } else {
                Add-Finding -ControlId "NSG-1" -ControlName "NSG Configuration" -Category "Network Security Groups" `
                    -ResourceType "Network Security Group" -ResourceName $nsg.name -ResourceGroup $nsg.resourceGroup `
                    -Finding "NSG not applied to any subnet" `
                    -Details "Orphaned NSG with no subnet associations" `
                    -Recommendation "Associate NSG to appropriate subnets or delete unused NSGs" `
                    -Criticality "Medium" -Status "Fail"
            }
            
            # NSG-3: Check flow logs
            $flowLogsEnabled = $nsg.flowLogs -and $nsg.flowLogs.Count -gt 0
            if (-not $flowLogsEnabled) {
                Add-Finding -ControlId "NSG-3" -ControlName "NSG Flow Logs" -Category "Network Security Groups" `
                    -ResourceType "Network Security Group" -ResourceName $nsg.name -ResourceGroup $nsg.resourceGroup `
                    -Finding "Flow logs not enabled" `
                    -Details "NSG: $($nsg.name) has no flow logs configured" `
                    -Recommendation "Enable NSG flow logs and send to Log Analytics Workspace or Storage Account for security analysis" `
                    -Criticality "High" -Status "Fail"
            } else {
                Add-Finding -ControlId "NSG-3" -ControlName "NSG Flow Logs" -Category "Network Security Groups" `
                    -ResourceType "Network Security Group" -ResourceName $nsg.name -ResourceGroup $nsg.resourceGroup `
                    -Finding "Flow logs enabled" `
                    -Details "Flow logs configured and active" `
                    -Recommendation "Ensure logs are retained >90 days and sent to Log Analytics for monitoring" `
                    -Criticality "Info" -Status "Pass"
            }
            
            # Analyze NSG rules
            $nsgRules = az network nsg rule list --nsg-name $nsg.name --resource-group $nsg.resourceGroup --query '[]' -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
            
            if ($nsgRules) {
                foreach ($rule in $nsgRules) {
                    if ($rule.access -eq 'Allow') {
                        # NSG-2: Check for broad allow rules (0.0.0.0/0)
                        if (($rule.sourceAddressPrefix -contains '*' -or $rule.sourceAddressPrefix -contains '0.0.0.0/0') -and 
                            ($rule.destinationPortRange -eq '3389' -or $rule.destinationPortRange -eq '*')) {
                            Add-Finding -ControlId "NSG-2,CIS-6.1" -ControlName "Broad Allow Rules / RDP Access" -Category "Network Security Groups" `
                                -ResourceType "NSG Rule" -ResourceName $rule.name -ResourceGroup $nsg.resourceGroup `
                                -Finding "Broad RDP access (0.0.0.0/0) detected" `
                                -Details "Rule: $($rule.name), Source: $($rule.sourceAddressPrefix), Destination Port: $($rule.destinationPortRange)" `
                                -Recommendation "Restrict RDP (port 3389) to specific source IPs or use Azure Bastion for secure access" `
                                -Criticality "Critical" -Status "Fail"
                            $broadAllowCount++
                        }
                        
                        if (($rule.sourceAddressPrefix -contains '*' -or $rule.sourceAddressPrefix -contains '0.0.0.0/0') -and 
                            ($rule.destinationPortRange -eq '22' -or $rule.destinationPortRange -eq '*')) {
                            Add-Finding -ControlId "NSG-2,CIS-6.2" -ControlName "Broad Allow Rules / SSH Access" -Category "Network Security Groups" `
                                -ResourceType "NSG Rule" -ResourceName $rule.name -ResourceGroup $nsg.resourceGroup `
                                -Finding "Broad SSH access (0.0.0.0/0) detected" `
                                -Details "Rule: $($rule.name), Source: $($rule.sourceAddressPrefix), Destination Port: $($rule.destinationPortRange)" `
                                -Recommendation "Restrict SSH (port 22) to specific source IPs or use Azure Bastion for secure access" `
                                -Criticality "Critical" -Status "Fail"
                            $broadAllowCount++
                        }
                        
                        if (($rule.sourceAddressPrefix -contains '*' -or $rule.sourceAddressPrefix -contains '0.0.0.0/0') -and 
                            ($rule.destinationPortRange -eq '1433' -or $rule.destinationPortRange -eq '*')) {
                            Add-Finding -ControlId "NSG-2,CIS-6.3" -ControlName "Broad Allow Rules / SQL Access" -Category "Network Security Groups" `
                                -ResourceType "NSG Rule" -ResourceName $rule.name -ResourceGroup $nsg.resourceGroup `
                                -Finding "Broad SQL Server access (0.0.0.0/0) detected" `
                                -Details "Rule: $($rule.name), Source: $($rule.sourceAddressPrefix), Destination Port: $($rule.destinationPortRange)" `
                                -Recommendation "Restrict SQL access to specific source IPs and use Private Endpoints when possible" `
                                -Criticality "Critical" -Status "Fail"
                            $broadAllowCount++
                        }
                    }
                    
                    # NSG-5: Check for service tags
                    if ($rule.sourceAddressPrefix -like 'Microsoft.*' -or $rule.sourceAddressPrefix -like 'Azure.*') {
                        Add-Finding -ControlId "NSG-5" -ControlName "Service Tag Usage" -Category "Network Security Groups" `
                            -ResourceType "NSG Rule" -ResourceName $rule.name -ResourceGroup $nsg.resourceGroup `
                            -Finding "Service tag implemented" `
                            -Details "Rule uses service tag: $($rule.sourceAddressPrefix)" `
                            -Recommendation "Continue using service tags instead of IP addresses for better maintainability" `
                            -Criticality "Info" -Status "Pass"
                    }
                }
            }
        }
        
        # Summary for NSG-2
        if ($broadAllowCount -eq 0) {
            Add-Finding -ControlId "NSG-2" -ControlName "Broad Allow Rules Check" -Category "Network Security Groups" `
                -ResourceType "Network Security Group" -ResourceName "All NSGs" -ResourceGroup "All" `
                -Finding "No critical broad allow rules detected" `
                -Details "Reviewed all NSG rules for 0.0.0.0/0 with unrestricted ports" `
                -Recommendation "Maintain restricted access patterns and regularly review NSG rules" `
                -Criticality "Info" -Status "Pass"
        }
    }
} catch {
    Write-Status "  Error assessing NSGs: $_"
}

# ===========================
# 3. AZURE FIREWALL & TRAFFIC FILTERING
# ===========================
Write-Status "Category 3: Azure Firewall & Traffic Filtering"

try {
    $firewalls = az network firewall list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $firewalls -or $firewalls.Count -eq 0) {
        Add-Finding -ControlId "FW-1" -ControlName "Azure Firewall Deployment" -Category "Firewall" `
            -ResourceType "Azure Firewall" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Azure Firewall instances found" `
            -Details "Zero firewalls in subscription" `
            -Recommendation "Deploy Azure Firewall at network boundaries with threat intelligence enabled for centralized threat protection" `
            -Criticality "High" -Status "Fail"
    } else {
        foreach ($fw in $firewalls) {
            Write-Status "  Checking Azure Firewall: $($fw.name)"
            
            Add-Finding -ControlId "FW-1" -ControlName "Azure Firewall Deployment" -Category "Firewall" `
                -ResourceType "Azure Firewall" -ResourceName $fw.name -ResourceGroup $fw.resourceGroup `
                -Finding "Azure Firewall deployed" `
                -Details "Firewall: $($fw.name), SKU: $($fw.sku.name), Zones: $($fw.zones -join ',')" `
                -Recommendation "Ensure threat intelligence is enabled and firewall policies are centrally managed" `
                -Criticality "Info" -Status "Pass"
        }
    }
} catch {
    Write-Status "  Error assessing Azure Firewall: $_"
}

# Check for Firewall Policies
Write-Status "  Checking Firewall Policies..."
try {
    $fwPolicies = az network firewall policy list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($fwPolicies -and $fwPolicies.Count -gt 0) {
        Add-Finding -ControlId "FW-2" -ControlName "Firewall Manager Policies" -Category "Firewall" `
            -ResourceType "Firewall Policy" -ResourceName ($fwPolicies[0].name) -ResourceGroup ($fwPolicies[0].resourceGroup) `
            -Finding "Firewall policies configured" `
            -Details "Number of policies: $($fwPolicies.Count)" `
            -Recommendation "Use Azure Firewall Manager for centralized policy management across multiple firewalls" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "FW-2" -ControlName "Firewall Manager Policies" -Category "Firewall" `
            -ResourceType "Firewall Policy" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Firewall policies configured" `
            -Details "Firewall Manager not in use" `
            -Recommendation "Implement centralized firewall policy management using Azure Firewall Manager" `
            -Criticality "Medium" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking firewall policies: $_"
}

# Check for WAF
Write-Status "  Checking Web Application Firewall..."
try {
    $wafPolicies = az network waf-policy list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($wafPolicies -and $wafPolicies.Count -gt 0) {
        Add-Finding -ControlId "FW-4" -ControlName "WAF Deployment" -Category "Firewall" `
            -ResourceType "WAF Policy" -ResourceName ($wafPolicies[0].name) -ResourceGroup ($wafPolicies[0].resourceGroup) `
            -Finding "WAF policies deployed" `
            -Details "Number of WAF policies: $($wafPolicies.Count)" `
            -Recommendation "Ensure WAF policies are applied to all web applications and updated regularly" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "FW-4" -ControlName "WAF Deployment" -Category "Firewall" `
            -ResourceType "WAF Policy" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No WAF policies found" `
            -Details "Web applications may lack protection" `
            -Recommendation "Implement WAF (Azure Application Gateway WAF or Front Door WAF) for web application protection" `
            -Criticality "High" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking WAF: $_"
}

# ===========================
# 4. PRIVATE CONNECTIVITY & ENDPOINTS
# ===========================
Write-Status "Category 4: Private Connectivity & Endpoints"

try {
    $privateEndpoints = az network private-endpoint list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $privateEndpoints -or $privateEndpoints.Count -eq 0) {
        Add-Finding -ControlId "PE-1" -ControlName "Private Endpoint Deployment" -Category "Private Endpoints" `
            -ResourceType "Private Endpoint" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Private Endpoints found" `
            -Details "Zero private endpoints in subscription" `
            -Recommendation "Deploy Private Endpoints for all Azure PaaS services (Storage, SQL, Key Vault, etc.) to avoid internet exposure" `
            -Criticality "High" -Status "Fail"
    } else {
        Add-Finding -ControlId "PE-1" -ControlName "Private Endpoint Deployment" -Category "Private Endpoints" `
            -ResourceType "Private Endpoint" -ResourceName ($privateEndpoints[0].name) -ResourceGroup ($privateEndpoints[0].resourceGroup) `
            -Finding "Private Endpoints implemented" `
            -Details "Number of private endpoints: $($privateEndpoints.Count)" `
            -Recommendation "Continue deploying Private Endpoints for all PaaS services and disable public network access" `
            -Criticality "Info" -Status "Pass"
    }
} catch {
    Write-Status "  Error assessing Private Endpoints: $_"
}

# Check for Private DNS Zones
Write-Status "  Checking Private DNS Zones..."
try {
    $privateDnsZones = az network private-dns zone list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($privateDnsZones -and $privateDnsZones.Count -gt 0) {
        Add-Finding -ControlId "PE-5,DNS-1" -ControlName "Private DNS Zone Configuration" -Category "Private Endpoints" `
            -ResourceType "Private DNS Zone" -ResourceName ($privateDnsZones[0].name) -ResourceGroup ($privateDnsZones[0].resourceGroup) `
            -Finding "Private DNS zones configured" `
            -Details "Number of private DNS zones: $($privateDnsZones.Count)" `
            -Recommendation "Ensure all private DNS zones are properly linked to VNets for private endpoint resolution" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "PE-5,DNS-1" -ControlName "Private DNS Zone Configuration" -Category "Private Endpoints" `
            -ResourceType "Private DNS Zone" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Private DNS zones found" `
            -Details "Private endpoint name resolution may fail without private DNS zones" `
            -Recommendation "Create and configure Private DNS zones for private endpoint name resolution (e.g., privatelink.database.windows.net)" `
            -Criticality "High" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking Private DNS zones: $_"
}

# ===========================
# 5. VPN & EXPRESSROUTE CONNECTIVITY
# ===========================
Write-Status "Category 5: VPN & ExpressRoute Connectivity"

try {
    $vpnGateways = az network vnet-gateway list --query "[?type=='Vpn']" -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $vpnGateways -or $vpnGateways.Count -eq 0) {
        Add-Finding -ControlId "VPN-1" -ControlName "VPN Gateway Configuration" -Category "VPN & ExpressRoute" `
            -ResourceType "VPN Gateway" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No VPN Gateways found" `
            -Details "Zero VPN gateways in subscription" `
            -Recommendation "Deploy Azure VPN Gateway with encrypted tunnels for site-to-site or point-to-site connectivity" `
            -Criticality "Medium" -Status "No Resources"
    } else {
        foreach ($vpnGw in $vpnGateways) {
            Add-Finding -ControlId "VPN-1" -ControlName "VPN Gateway Configuration" -Category "VPN & ExpressRoute" `
                -ResourceType "VPN Gateway" -ResourceName $vpnGw.name -ResourceGroup $vpnGw.resourceGroup `
                -Finding "VPN Gateway deployed" `
                -Details "Gateway: $($vpnGw.name), SKU: $($vpnGw.sku.name), Type: $($vpnGw.gatewayType)" `
                -Recommendation "Ensure VPN gateway uses strong encryption (IKEv2, AES-256) and connections are monitored" `
                -Criticality "Info" -Status "Pass"
        }
    }
    
    # Check ExpressRoute Gateways
    $erGateways = az network vnet-gateway list --query "[?type=='ExpressRoute']" -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($erGateways -and $erGateways.Count -gt 0) {
        foreach ($erGw in $erGateways) {
            Add-Finding -ControlId "VPN-2" -ControlName "ExpressRoute Gateway" -Category "VPN & ExpressRoute" `
                -ResourceType "ExpressRoute Gateway" -ResourceName $erGw.name -ResourceGroup $erGw.resourceGroup `
                -Finding "ExpressRoute Gateway deployed" `
                -Details "Gateway: $($erGw.name), SKU: $($erGw.sku.name)" `
                -Recommendation "Implement MACsec and IPsec encryption for ExpressRoute connections and configure backup VPN" `
                -Criticality "Info" -Status "Pass"
        }
    } else {
        Add-Finding -ControlId "VPN-2" -ControlName "ExpressRoute Gateway" -Category "VPN & ExpressRoute" `
            -ResourceType "ExpressRoute Gateway" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No ExpressRoute Gateways found" `
            -Details "ExpressRoute not implemented" `
            -Recommendation "Consider ExpressRoute for dedicated, private, and high-bandwidth connectivity to Azure" `
            -Criticality "Low" -Status "No Resources"
    }
} catch {
    Write-Status "  Error assessing VPN/ExpressRoute: $_"
}

# ===========================
# 6. DDOS PROTECTION
# ===========================
Write-Status "Category 6: DDoS Protection"

try {
    $ddosPlans = az network ddos-protection list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    foreach ($vnet in $vnets) {
        $ddosEnabled = $vnet.enableDdosProtection -eq $true
        
        if ($ddosEnabled) {
            Add-Finding -ControlId "DDOS-1" -ControlName "DDoS Protection Standard" -Category "DDoS Protection" `
                -ResourceType "Virtual Network" -ResourceName $vnet.name -ResourceGroup $vnet.resourceGroup `
                -Finding "DDoS Protection Standard enabled" `
                -Details "VNet: $($vnet.name)" `
                -Recommendation "Ensure DDoS protection plan is active and alerts are configured" `
                -Criticality "Info" -Status "Pass"
        } else {
            Add-Finding -ControlId "DDOS-1" -ControlName "DDoS Protection Standard" -Category "DDoS Protection" `
                -ResourceType "Virtual Network" -ResourceName $vnet.name -ResourceGroup $vnet.resourceGroup `
                -Finding "DDoS Protection Standard not enabled" `
                -Details "VNet: $($vnet.name) - DDoS Standard not active" `
                -Recommendation "Enable Azure DDoS Protection Standard on critical VNets for layer 3-4 protection" `
                -Criticality "High" -Status "Fail"
        }
    }
    
    if ($ddosPlans -and $ddosPlans.Count -gt 0) {
        Add-Finding -ControlId "DDOS-2" -ControlName "DDoS Telemetry and Alerts" -Category "DDoS Protection" `
            -ResourceType "DDoS Protection Plan" -ResourceName ($ddosPlans[0].name) -ResourceGroup ($ddosPlans[0].resourceGroup) `
            -Finding "DDoS protection plan deployed" `
            -Details "DDoS plans: $($ddosPlans.Count)" `
            -Recommendation "Configure DDoS telemetry, alerts, and response procedures" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "DDOS-1,DDOS-2" -ControlName "DDoS Protection Plan" -Category "DDoS Protection" `
            -ResourceType "DDoS Protection Plan" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No DDoS Protection plans found" `
            -Details "DDoS Basic protection only (default)" `
            -Recommendation "Deploy DDoS Protection Standard plan and configure telemetry and alerts for advanced threat detection" `
            -Criticality "High" -Status "Fail"
    }
} catch {
    Write-Status "  Error assessing DDoS Protection: $_"
}

# ===========================
# 7. DNS SECURITY
# ===========================
Write-Status "Category 7: DNS Security"

try {
    $dnsZones = az network dns zone list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $dnsZones -or $dnsZones.Count -eq 0) {
        Add-Finding -ControlId "DNS-1" -ControlName "Public DNS Zone Configuration" -Category "DNS Security" `
            -ResourceType "DNS Zone" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No public DNS zones found" `
            -Details "Consider using Azure DNS for domain management" `
            -Recommendation "For private services, use Private DNS zones (already checked in PE-5). Use Azure DNS for public zones" `
            -Criticality "Low" -Status "Info"
    } else {
        foreach ($dnsZone in $dnsZones) {
            Add-Finding -ControlId "DNS-1" -ControlName "DNS Zone Configuration" -Category "DNS Security" `
                -ResourceType "DNS Zone" -ResourceName $dnsZone.name -ResourceGroup $dnsZone.resourceGroup `
                -Finding "DNS zone hosted: $($dnsZone.name)" `
                -Details "Zone type: Public, Nameservers: Configured" `
                -Recommendation "Protect DNS zone from unauthorized modification using RBAC and resource locks" `
                -Criticality "Info" -Status "Pass"
        }
    }
} catch {
    Write-Status "  Error assessing DNS: $_"
}

# ===========================
# 8. NETWORK MONITORING & LOGGING
# ===========================
Write-Status "Category 8: Network Monitoring & Logging"

try {
    $nwWatchers = az network watcher list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if (-not $nwWatchers -or $nwWatchers.Count -eq 0) {
        Add-Finding -ControlId "MON-1,CIS-6.4,CIS-6.6" -ControlName "Network Watcher Deployment" -Category "Network Monitoring" `
            -ResourceType "Network Watcher" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "Network Watcher not enabled" `
            -Details "No Network Watcher instances found" `
            -Recommendation "Enable Network Watcher in all regions for traffic monitoring and diagnostics" `
            -Criticality "High" -Status "Fail"
    } else {
        Add-Finding -ControlId "MON-1,CIS-6.4,CIS-6.6" -ControlName "Network Watcher Deployment" -Category "Network Monitoring" `
            -ResourceType "Network Watcher" -ResourceName ($nwWatchers[0].name) -ResourceGroup ($nwWatchers[0].resourceGroup) `
            -Finding "Network Watcher enabled" `
            -Details "Network Watchers in $($nwWatchers.Count) region(s)" `
            -Recommendation "Ensure Network Watcher is deployed in all regions where resources are deployed" `
            -Criticality "Info" -Status "Pass"
    }
} catch {
    Write-Status "  Error assessing Network Watcher: $_"
}

# Check for Log Analytics workspace
Write-Status "  Checking Log Analytics configuration..."
try {
    $logAnalyticsWs = az monitor log-analytics workspace list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($logAnalyticsWs -and $logAnalyticsWs.Count -gt 0) {
        Add-Finding -ControlId "MON-4" -ControlName "Log Analytics Configuration" -Category "Network Monitoring" `
            -ResourceType "Log Analytics Workspace" -ResourceName ($logAnalyticsWs[0].name) -ResourceGroup ($logAnalyticsWs[0].resourceGroup) `
            -Finding "Log Analytics workspace configured" `
            -Details "Number of workspaces: $($logAnalyticsWs.Count)" `
            -Recommendation "Send all network logs (NSG flow logs, firewall logs, diagnostics) to Log Analytics for centralized monitoring" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "MON-4" -ControlName "Log Analytics Configuration" -Category "Network Monitoring" `
            -ResourceType "Log Analytics Workspace" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No Log Analytics workspace found" `
            -Details "Network logs are not centralized" `
            -Recommendation "Create a Log Analytics workspace and send all network diagnostics for monitoring and threat detection" `
            -Criticality "High" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking Log Analytics: $_"
}

# Check for Azure Sentinel
Write-Status "  Checking Azure Sentinel configuration..."
try {
    $sentinel = az sentinel workspace-manager list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($sentinel -and $sentinel.Count -gt 0) {
        Add-Finding -ControlId "MON-6" -ControlName "Azure Sentinel Deployment" -Category "Network Monitoring" `
            -ResourceType "Azure Sentinel" -ResourceName "Configured" -ResourceGroup "Various" `
            -Finding "Azure Sentinel is enabled" `
            -Details "Advanced threat detection is active" `
            -Recommendation "Ensure Sentinel is monitoring network logs and configured with security analytics rules" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "MON-6" -ControlName "Azure Sentinel Deployment" -Category "Network Monitoring" `
            -ResourceType "Azure Sentinel" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "Azure Sentinel not enabled" `
            -Details "Advanced threat detection not configured" `
            -Recommendation "Enable Azure Sentinel on Log Analytics workspace for advanced threat detection and security analytics" `
            -Criticality "Medium" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking Sentinel: $_"
}

# ===========================
# 9. IDENTITY & NETWORK ACCESS CONTROL
# ===========================
Write-Status "Category 9: Identity & Network Access Control"

try {
    # Check for Azure Bastion with timeout
    Write-Status "  Checking Azure Bastion (timeout: 10 seconds)..."
    $bastions = $null
    try {
        $bastionJob = Start-Job -ScriptBlock { az network bastion list --query '[]' -o json 2>$null }
        $jobResult = Wait-Job -Job $bastionJob -Timeout 10 -ErrorAction SilentlyContinue
        
        if ($jobResult) {
            $bastionOutput = Receive-Job -Job $bastionJob -ErrorAction SilentlyContinue
            if ($bastionOutput) {
                $bastions = $bastionOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
            }
        } else {
            Write-Status "  Bastion query timed out, skipping..."
        }
        Remove-Job -Job $bastionJob -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Status "  Error querying Bastion: $_"
    }
    
    if ($bastions -and $bastions.Count -gt 0) {
        Add-Finding -ControlId "IAM-2" -ControlName "Azure Bastion Deployment" -Category "Identity & Access Control" `
            -ResourceType "Azure Bastion" -ResourceName ($bastions[0].name) -ResourceGroup ($bastions[0].resourceGroup) `
            -Finding "Azure Bastion deployed" `
            -Details "Number of Bastion instances: $($bastions.Count)" `
            -Recommendation "Use Bastion for secure VM access without public IPs and RDP/SSH exposed" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "IAM-2" -ControlName "Azure Bastion Deployment" -Category "Identity & Access Control" `
            -ResourceType "Azure Bastion" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "Azure Bastion not deployed" `
            -Details "VMs may be exposed via RDP/SSH" `
            -Recommendation "Deploy Azure Bastion to provide secure, browser-based VM access without public IPs" `
            -Criticality "High" -Status "Fail"
    }
} catch {
    Write-Status "  Error assessing Bastion: $_"
}

# ===========================
# 10. NETWORK SECURITY CONFIGURATION & GOVERNANCE
# ===========================
Write-Status "Category 10: Network Security Configuration & Governance"

try {
    $policies = @()
    try {
        $policies = az policy definition list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        $policies = $policies | Where-Object { $_.displayName -match 'Network|NSG|Firewall|Security' }
    } catch {
        Write-Status "  Note: Policy query returned no results or timed out"
    }
    
    if ($policies -and $policies.Count -gt 0) {
        Add-Finding -ControlId "GOV-1" -ControlName "Azure Policy for Network Security" -Category "Governance" `
            -ResourceType "Azure Policy" -ResourceName "Network Policies" -ResourceGroup "Various" `
            -Finding "Network security policies configured" `
            -Details "Number of network-related policies: $($policies.Count)" `
            -Recommendation "Use Azure Policy to enforce network security requirements (NSG rules, firewall deployment, etc.)" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "GOV-1" -ControlName "Azure Policy for Network Security" -Category "Governance" `
            -ResourceType "Azure Policy" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No network security policies found" `
            -Details "Governance policies not defined" `
            -Recommendation "Define and apply Azure Policy definitions to enforce network security controls across resources" `
            -Criticality "Medium" -Status "Fail"
    }
} catch {
    Write-Status "  Error assessing policies: $_"
}

# Check for tagging strategy
Write-Status "  Checking resource tagging strategy..."
try {
    $allResources = az resource list --query '[0:10]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    $taggedCount = ($allResources | Where-Object { $_.tags -and $_.tags.Count -gt 0 }).Count
    
    if ($allResources -and $allResources.Count -gt 0) {
        $taggingPercentage = if ($allResources.Count -gt 0) { [int]($taggedCount / $allResources.Count * 100) } else { 0 }
        
        if ($taggingPercentage -ge 80) {
            Add-Finding -ControlId "GOV-3" -ControlName "Resource Tagging Strategy" -Category "Governance" `
                -ResourceType "All Resources" -ResourceName "Network Resources" -ResourceGroup "Various" `
                -Finding "Tagging strategy implemented" `
                -Details "Tagging compliance: $taggingPercentage% of sampled resources" `
                -Recommendation "Maintain consistent tagging for cost tracking, automation, and compliance" `
                -Criticality "Info" -Status "Pass"
        } else {
            Add-Finding -ControlId "GOV-3" -ControlName "Resource Tagging Strategy" -Category "Governance" `
                -ResourceType "All Resources" -ResourceName "Network Resources" -ResourceGroup "Various" `
                -Finding "Tagging strategy needs improvement" `
                -Details "Tagging compliance: $taggingPercentage% of sampled resources" `
                -Recommendation "Implement consistent tagging strategy for network resources (Owner, CostCenter, Environment, etc.)" `
                -Criticality "Medium" -Status "Fail"
        }
    }
} catch {
    Write-Status "  Error checking tagging: $_"
}

# ===========================
# 11. ADDITIONAL SECURITY CONTROLS
# ===========================
Write-Status "Category 11: Additional Security Controls"

try {
    # Check public IPs
    $publicIps = az network public-ip list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($publicIps -and $publicIps.Count -gt 0) {
        $unassociatedIps = $publicIps | Where-Object { -not $_.ipConfiguration }
        
        Add-Finding -ControlId "SEC-4" -ControlName "Public IP Address Usage" -Category "Additional Security" `
            -ResourceType "Public IP" -ResourceName ($publicIps[0].name) -ResourceGroup ($publicIps[0].resourceGroup) `
            -Finding "Public IP addresses in use" `
            -Details "Total public IPs: $($publicIps.Count), Unassociated: $($unassociatedIps.Count)" `
            -Recommendation "Minimize public IP usage. Use Private Endpoints, Bastion, or NAT Gateway instead" `
            -Criticality "Medium" -Status "Pass"
    } else {
        Add-Finding -ControlId "SEC-4" -ControlName "Public IP Address Usage" -Category "Additional Security" `
            -ResourceType "Public IP" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No public IPs found" `
            -Details "Resources may not be internet-facing or well-protected" `
            -Recommendation "Continue minimizing public IPs and use secure access methods like Bastion" `
            -Criticality "Info" -Status "Pass"
    }
} catch {
    Write-Status "  Error checking public IPs: $_"
}

# Check for User Defined Routes (UDRs)
Write-Status "  Checking User Defined Routes..."
try {
    $routeTables = az network route-table list --query '[]' -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($routeTables -and $routeTables.Count -gt 0) {
        Add-Finding -ControlId "SEC-2" -ControlName "User Defined Routes (UDRs)" -Category "Additional Security" `
            -ResourceType "Route Table" -ResourceName ($routeTables[0].name) -ResourceGroup ($routeTables[0].resourceGroup) `
            -Finding "UDRs configured" `
            -Details "Number of route tables: $($routeTables.Count)" `
            -Recommendation "Use UDRs to force traffic through security appliances (firewalls, WAF, NVAs)" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "SEC-2" -ControlName "User Defined Routes (UDRs)" -Category "Additional Security" `
            -ResourceType "Route Table" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No custom route tables found" `
            -Details "Default routing in use" `
            -Recommendation "Implement UDRs to control traffic flow through security appliances for defense-in-depth" `
            -Criticality "Low" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking UDRs: $_"
}

# Check for Availability Zones
Write-Status "  Checking Availability Zone implementation..."
try {
    $vmsWithZones = 0
    try {
        $vmsWithZonesOutput = az vm list --query "[?zones] | length(@)" -o tsv 2>$null
        $vmsWithZones = [int]$vmsWithZonesOutput
    } catch {
        $vmsWithZones = 0
    }
    
    if ($vmsWithZones -gt 0) {
        Add-Finding -ControlId "SEC-5" -ControlName "Availability Zones" -Category "Additional Security" `
            -ResourceType "Virtual Machine" -ResourceName "Various" -ResourceGroup "Various" `
            -Finding "Resources deployed across Availability Zones" `
            -Details "VMs with zone redundancy: $vmsWithZones" `
            -Recommendation "Continue using Availability Zones for high availability and disaster recovery" `
            -Criticality "Info" -Status "Pass"
    } else {
        Add-Finding -ControlId "SEC-5" -ControlName "Availability Zones" -Category "Additional Security" `
            -ResourceType "Virtual Machine" -ResourceName "N/A" -ResourceGroup "N/A" `
            -Finding "No zone-redundant resources found" `
            -Details "Resources may not have high availability" `
            -Recommendation "Deploy critical resources across Availability Zones for high availability" `
            -Criticality "Medium" -Status "Fail"
    }
} catch {
    Write-Status "  Error checking Availability Zones: $_"
}

# ===========================
# EXPORT RESULTS
# ===========================
Write-Status "Assessment complete. Exporting results..."

if ($findings.Count -eq 0) {
    Write-Host "
Warning: No findings recorded!" -ForegroundColor Yellow
} else {
    $criticalityOrder = @{'Critical' = 0; 'High' = 1; 'Medium' = 2; 'Low' = 3; 'Info' = 4; 'No Resources' = 5}
    $findings = $findings | Sort-Object { $criticalityOrder[$_.Criticality] }
}

$findings | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

# Generate Summary Report
$critical = ($findings | Where-Object { $_.Criticality -eq 'Critical' }).Count
$high = ($findings | Where-Object { $_.Criticality -eq 'High' }).Count
$medium = ($findings | Where-Object { $_.Criticality -eq 'Medium' }).Count
$low = ($findings | Where-Object { $_.Criticality -eq 'Low' }).Count
$info = ($findings | Where-Object { $_.Criticality -eq 'Info' }).Count
$passCount = ($findings | Where-Object { $_.Status -eq 'Pass' }).Count
$failCount = ($findings | Where-Object { $_.Status -eq 'Fail' }).Count

Write-Host "
================================================================================
Azure Networking Configuration Assessment - Summary Report
================================================================================
Subscription: $subscriptionName
Assessment Date: $assessmentDate
Total Findings: $($findings.Count)

FINDINGS BY CRITICALITY:
  Critical: $critical $(if($critical -gt 0) { '⚠️' } else { '✓' })
  High:     $high $(if($high -gt 0) { '⚠️' } else { '✓' })
  Medium:   $medium
  Low:      $low
  Info:     $info

FINDINGS BY STATUS:
  Pass:     $passCount ✓
  Fail:     $failCount ✗

CATEGORIES ASSESSED:
  1. Network Segmentation & Architecture
  2. Network Security Groups (NSGs)
  3. Azure Firewall & Traffic Filtering
  4. Private Connectivity & Endpoints
  5. VPN & ExpressRoute Connectivity
  6. DDoS Protection
  7. DNS Security
  8. Network Monitoring & Logging
  9. Identity & Network Access Control
  10. Network Security Configuration & Governance
  11. Additional Security Controls

================================================================================
Detailed Report: $OutputPath
================================================================================
" -ForegroundColor Cyan

Write-Host "Export completed successfully!" -ForegroundColor Green
