Assessment Control Categories
1. Network Segmentation & Architecture

NS-1: Implement network segmentation using Virtual Networks (VNets) and subnets based on security zones [1]
NS-2: Avoid small virtual networks and subnets; use CIDR-based subnetting principles [2]
NS-3: Create network access controls between subnets using NSGs [2]
NS-4: Implement hub-and-spoke or Virtual WAN architecture for centralized management [3]
NS-5: Use Application Security Groups (ASGs) to simplify complex security configurations [4]

2. Network Security Groups (NSGs)

NSG-1: Ensure all Virtual Network subnets have NSGs applied (except GatewaySubnet, AzureFirewallSubnet) [5]
NSG-2: Avoid broad allow rules (0.0.0.0/0 to 255.255.255.255) [2]
NSG-3: Enable NSG flow logs and send to Log Analytics/Storage Account [5]
NSG-4: Use Traffic Analytics to visualize network activity and identify security threats [5]
NSG-5: Use service tags in NSG rules instead of specific IP addresses [4]
NSG-6: Use descriptive names and documentation for NSG rules [6]
NSG-7: Review and update NSG rules regularly to align with current architecture [3]

3. Azure Firewall & Traffic Filtering

FW-1: Deploy Azure Firewall at network boundaries with threat intelligence enabled [4]
FW-2: Use Azure Firewall Manager for centralized policy and route management [1]
FW-3: Route all internet-bound traffic through a centralized firewall [7]
FW-4: Implement Web Application Firewall (WAF) for web applications [5]
FW-5: Enable diagnostic logging for Azure Firewall and WAF [5]
FW-6: Block known malicious IP addresses and high-risk protocols (RDP, SSH, SMB) [1]
FW-7: Use FQDN filtering for internet access control [3]

4. Private Connectivity & Endpoints

PE-1: Deploy Private Endpoints for all Azure PaaS services that support Private Link [1]
PE-2: Disable public network access to services where feasible [1]
PE-3: Use VNet integration for supported services [1]
PE-4: Use Service Endpoints when Private Link is not available [4]
PE-5: Configure Azure Private DNS zones for private endpoint name resolution [1]

5. VPN & ExpressRoute Connectivity

VPN-1: Use Azure VPN Gateway with encrypted tunnels for site-to-site connectivity [8]
VPN-2: Implement ExpressRoute for dedicated, private connectivity to Azure [4]
VPN-3: Configure MACsec encryption for ExpressRoute Direct connections [8]
VPN-4: Implement IPsec VPN over ExpressRoute for additional encryption [8]
VPN-5: Use site-to-site VPN as backup for ExpressRoute [8]
VPN-6: Ensure 4-byte ASN support for all gateways [9]
VPN-7: Use just-in-time access for VPN connections [2]

6. DDoS Protection

DDOS-1: Enable Azure DDoS Protection Standard on all virtual networks [5]
DDOS-2: Configure DDoS protection telemetry and alerts [4]
DDOS-3: Implement DDoS response plan and testing procedures [10]

7. DNS Security

DNS-1: Use Azure Private DNS for private DNS zones within VNets [1]
DNS-2: Protect DNS zones from unauthorized modification using RBAC and resource locks [4]
DNS-3: Use Azure Defender for DNS for threat protection [1]
DNS-4: Implement custom DNS to restrict resolution to trusted sources [1]

8. Network Monitoring & Logging

MON-1: Enable Network Watcher in all regions [11]
MON-2: Use Network Watcher tools (Connection Monitor, Flow logs, Packet Capture) [12]
MON-3: Configure diagnostic settings for all network resources [8]
MON-4: Send network logs to Log Analytics workspace [5]
MON-5: Set up alerts for network anomalies and security events [12]
MON-6: Use Azure Sentinel for advanced threat detection [1]

9. Identity & Network Access Control

IAM-1: Use Microsoft Entra Conditional Access for network location-based policies [2]
IAM-2: Use Azure Bastion for secure VM access without public IPs [2]
IAM-3: Implement just-in-time VM access in Microsoft Defender for Cloud [2]
IAM-4: Use managed identities for Azure resources [7]

10. Network Security Configuration & Governance

GOV-1: Define network security policies using Azure Policy [5]
GOV-2: Use Azure Blueprints for consistent network deployments [5]
GOV-3: Implement tagging strategy for network resources [5]
GOV-4: Regular compliance audits against CIS Azure Foundations Benchmark [13]
GOV-5: Use Azure Virtual Network Manager for centralized network management [3]

11. CIS Azure Foundations Benchmark - Networking Controls

CIS-6.1: Ensure RDP access is restricted from the internet [14]
CIS-6.2: Ensure SSH access is restricted from the internet [14]
CIS-6.3: Ensure SQL server access is restricted [14]
CIS-6.4: Ensure Network Watcher is enabled [14]
CIS-6.5: Ensure that Network Security Group Flow Logs retention is set to greater than 90 days [14]
CIS-6.6: Ensure that Network Watcher is enabled for all regions [14]

12. Additional Security Controls

SEC-1: Detect and disable insecure protocols (SSL/TLSv1, SSHv1, SMBv1) [1]
SEC-2: Use route tables (UDRs) to force traffic through security appliances [1]
SEC-3: Implement network segmentation with defense-in-depth approach [7]
SEC-4: Minimize public IP address usage [3]
SEC-5: Use Availability Zones for high availability [12]

References
[1] Azure Security Benchmark v3 - Network Security
[2] Best practices for network security - Microsoft Azure
[3] Architecture Best Practices for Azure Virtual Network
[4] Azure Security Benchmark V2 - Network Security
[5] Azure Security Control - Network Security
[6] Azure Network Security Groups: Best Practices - Kainos
[7] Architecture strategies for networking and connectivity - Azure Well-Architected Framework
[8] Secure your Azure ExpressRoute
[9] Network planning checklist - Azure VMware Solution
[10] Azure security best practices checklist - Astra
[11] Azure network security overview
[12] Best Practices for Preventing and Mitigating Intermittent Network Connectivity Issues
[13] Center for Internet Security (CIS) Benchmarks - Microsoft Compliance
[14] CIS Azure Foundations Benchmark - Check Point Blog