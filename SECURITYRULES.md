CIS Azure Foundations Benchmark Controls by Category
1. NETWORKING (Section 6 - 7 Controls)
CIS 6.1: Ensure that RDP access is restricted from the internet (Automated) [1]
CIS 6.2: Ensure that SSH access is restricted from the internet (Automated) [1]
CIS 6.3: Ensure no SQL Databases allow ingress 0.0.0.0/0 (ANY IP) (Automated) [1]
CIS 6.4: Ensure that Network Security Group Flow Log retention period is 'greater than 90 days' (Automated) [1]
CIS 6.5: Ensure that Network Watcher is enabled (Automated) [2]
CIS 6.6: Ensure that Public IP addresses are evaluated on a periodic basis (Manual) [1]
CIS 6.7: Ensure that VNet subnets are associated with Network Security Groups (Automated) [1]
2. APPLICATION (Section 9 - 11 Controls)
CIS 9.1: Ensure App Service Authentication is set up for apps in Azure App Service (Automated) [3]
CIS 9.2: Ensure Web App Redirects All HTTP traffic to HTTPS in Azure App Service (Automated) [3]
CIS 9.3: Ensure Web App is using the latest version of TLS encryption (Automated) [3]
CIS 9.4: Ensure the web app has 'Client Certificates (Incoming client certificates)' set to 'On' (Automated) [3]
CIS 9.5: Ensure that Register with Azure Active Directory is enabled on App Service (Automated) [3]
CIS 9.6: Ensure that '.NET Framework' version is the latest (Manual) [3]
CIS 9.7: Ensure that 'PHP version' is the latest (Manual) [3]
CIS 9.8: Ensure that 'Python version' is the latest (Manual) [3]
CIS 9.9: Ensure that 'Java version' is the latest (Manual) [3]
CIS 9.10: Ensure that 'HTTP Version' is the latest (Manual) [3]
CIS 9.11: Ensure that Azure Keyvaults are Used to Store Secrets (Manual) [3]
3. STORAGE (Section 3 - 15 Controls)
CIS 3.1: Ensure that 'Secure transfer required' is set to 'Enabled' (Automated) [4]
CIS 3.2: Ensure that 'Enable Infrastructure Encryption' for Each Storage Account in Azure Storage is Set to 'enabled' (Automated) [4]
CIS 3.3: Ensure that Storage Account Access Keys are Periodically Regenerated (Manual) [4]
CIS 3.4: Ensure that Shared Access Signature Tokens Expire Within an Hour (Manual) [4]
CIS 3.5: Ensure that Azure Storage uses private link (Manual) [4]
CIS 3.6: Ensure Default Network Access Rule for Storage Accounts is Set to Deny (Automated) [4]
CIS 3.7: Ensure 'Trusted Microsoft Services' are Enabled for Storage Account Access (Automated) [4]
CIS 3.8: Ensure Soft Delete is Enabled for Azure Storage (Automated) [4]
CIS 3.9: Ensure Storage for Critical Data are Encrypted with Customer Managed Keys (Manual) [4]
CIS 3.10: Ensure Storage logging is Enabled for Blob Service for 'Read', 'Write', and 'Delete' requests (Automated) [4]
CIS 3.11: Ensure Storage logging is Enabled for Queue Service for 'Read', 'Write', and 'Delete' requests (Automated) [4]
CIS 3.12: Ensure Storage Logging is Enabled for Table Service for 'Read', 'Write', and 'Delete' Requests (Automated) [4]
CIS 3.13: Ensure 'Allow Azure services on the trusted services list to access this storage account' is Enabled for Storage Account Access (Manual) [4]
CIS 3.14: Ensure Private Endpoints are used to access Storage Accounts (Manual) [4]
CIS 3.15: Ensure 'Minimum TLS version' is set to 'Version 1.2' (Automated) [4]
4. DATA / DATABASE SERVICES (Section 4 - Multiple Controls)
4.1 SQL Server - Auditing
CIS 4.1.1: Ensure that 'Auditing' is set to 'On' (Automated) [5]
CIS 4.1.2: Ensure that 'Data encryption' is set to 'On' on a SQL Database (Automated) [5]
CIS 4.1.3: Ensure that 'Auditing' Retention is 'greater than 90 days' (Automated) [5]
4.2 SQL Server - Azure Defender for SQL
CIS 4.2.1: Ensure that Advanced Threat Protection (ATP) on a SQL server is set to 'Enabled' (Automated) [5]
CIS 4.2.2: Ensure that Vulnerability Assessment (VA) is enabled on a SQL server by setting a Storage Account (Automated) [5]
CIS 4.2.3: Ensure that VA setting 'Periodic recurring scans' is set to 'on' for each SQL server (Automated) [5]
CIS 4.2.4: Ensure that VA setting 'Send scan reports to' is configured for a SQL server (Automated) [5]
CIS 4.2.5: Ensure that VA setting 'Also send email notifications to admins and subscription owners' is set for each SQL server (Automated) [5]
4.3 PostgreSQL Database Server
CIS 4.3.1: Ensure 'Enforce SSL connection' is set to 'ENABLED' for PostgreSQL Database Server (Automated) [5]
CIS 4.3.2: Ensure 'log_checkpoints' database flag for Cloud SQL PostgreSQL instance is set to 'on' (Automated) [5]
CIS 4.3.3: Ensure server parameter 'log_connections' is set to 'ON' for PostgreSQL Database Server (Automated) [5]
CIS 4.3.4: Ensure server parameter 'log_disconnections' is set to 'ON' for PostgreSQL Database Server (Automated) [5]
CIS 4.3.5: Ensure server parameter 'connection_throttling' is set to 'ON' for PostgreSQL Database Server (Automated) [5]
CIS 4.3.6: Ensure server parameter 'log_retention_days' is greater than 3 days for PostgreSQL Database Server (Automated) [5]
CIS 4.3.7: Ensure 'Allow access to Azure services' for PostgreSQL Database Server is disabled (Automated) [5]
CIS 4.3.8: Ensure 'Allow access to Azure services' for PostgreSQL Database Server is disabled (Manual) [5]
4.4 MySQL Database Server
CIS 4.4.1: Ensure 'Enforce SSL connection' is set to 'ENABLED' for MySQL Database Server (Automated) [5]
CIS 4.4.2: Ensure 'TLS Version' is set to 'TLSV1.2' for MySQL flexible Database Server (Automated) [5]
4.5 Additional Database Controls
CIS 4.5: Ensure that Azure Active Directory Admin is configured (Automated) [5]
CIS 4.5.3: Use Azure Active Directory (AAD) Client Authentication and Azure RBAC where possible (for Cosmos DB) [6]
CIS 4.6: Ensure SQL server's TDE protector is encrypted with Customer-managed key (Automated) [5]
5. ANALYTICS (Not explicitly covered as separate section, but includes Application Insights)
CIS 5.3.1: Ensure Application Insights are Configured (Automated - added in v2.0.0) [6]
6. OPERATIONS MANAGEMENT / LOGGING AND MONITORING (Section 5 - Multiple Controls)
5.1 Configuring Diagnostic Settings
CIS 5.1.1: Ensure that a 'Diagnostics Setting' exists (Manual) [7]
CIS 5.1.2: Ensure Diagnostic Setting captures appropriate categories (Manual) [7]
CIS 5.1.3: Ensure the storage container storing the activity logs is not publicly accessible (Automated) [7]
CIS 5.1.4: Ensure the storage account containing the container with activity logs is encrypted with BYOK (Use Your Own Key) (Automated) [7]
CIS 5.1.5: Ensure that logging for Azure KeyVault is 'Enabled' (Automated) [7]
5.2 Monitoring using Activity Log Alerts
CIS 5.2.1: Ensure that Activity Log Alert exists for Create Policy Assignment (Automated) [7]
CIS 5.2.2: Ensure that Activity Log Alert exists for Delete Policy Assignment (Automated) [7]
CIS 5.2.3: Ensure that Activity Log Alert exists for Create or Update Network Security Group (Automated) [7]
CIS 5.2.4: Ensure that Activity Log Alert exists for Delete Network Security Group (Automated) [7]
CIS 5.2.5: Ensure that Activity Log Alert exists for Create or Update Network Security Group Rule (Automated) [7]
CIS 5.2.6: Ensure that activity log alert exists for the Delete Network Security Group Rule (Automated) [7]
CIS 5.2.7: Ensure that Activity Log Alert exists for Create or Update Security Solution (Automated) [7]
CIS 5.2.8: Ensure that Activity Log Alert exists for Delete Security Solution (Automated) [7]
CIS 5.2.9: Ensure that Activity Log Alert exists for Create or Update SQL Server Firewall Rule (Automated) [7]
CIS 5.2.10: Ensure that Activity Log Alert exists for Delete SQL Server Firewall Rule (Automated) [7]
CIS 5.3: Ensure that Diagnostic Logs are enabled for all services which support it (Manual) [7]
7. VIRTUAL MACHINES / COMPUTE (Section 7 - 7 Controls)
CIS 7.1: Ensure Virtual Machines are utilizing Managed Disks (Manual) [8]
CIS 7.2: Ensure that 'OS and Data' disks are encrypted with Customer Managed Key (CMK) (Automated) [8]
CIS 7.3: Ensure that 'Unattached disks' are encrypted with CMK (Automated) [8]
CIS 7.4: Ensure that Only Approved Extensions Are Installed (Automated) [8]
CIS 7.5: Ensure that the latest OS Patches for all Virtual Machines are applied (Manual) [8]
CIS 7.6: Ensure that the endpoint protection for all Virtual Machines is installed (Manual) [8]
CIS 7.7: Ensure that VHD's are Encrypted (Manual) [8]
8. KEY VAULT (Section 8 - 8 Controls)
CIS 8.1: Ensure that the Expiration Date is set for all Keys in RBAC Key Vaults (Automated) [9]
CIS 8.2: Ensure that the Expiration Date is set for all Keys in Non-RBAC Key Vaults (Manual) [9]
CIS 8.3: Ensure that the Expiration Date is set for all Secrets in RBAC Key Vaults (Automated) [9]
CIS 8.4: Ensure that the Expiration Date is set for all Secrets in Non-RBAC Key Vaults (Manual) [9]
CIS 8.5: Ensure the key vault is recoverable (Automated) [9]
CIS 8.6: Enable Azure Private Link for Key Vault (Manual) [9]
CIS 8.7: Enable role-based access control (RBAC) within Azure Kubernetes Services (Automated) [9]
CIS 8.8: Ensure that key vault allows firewall rules settings (Manual) [9]
9. IDENTITY AND ACCESS MANAGEMENT (Section 1 - 33 Controls)
CIS 1.1: Ensure that multi-factor authentication is enabled for all privileged users (Automated) [10]
CIS 1.2: Ensure that multi-factor authentication is enabled for all non-privileged users (Automated) [10]
CIS 1.3: Ensure that there are no guest users (Manual) [10]
CIS 1.4: Ensure that 'Allow users to remember multi-factor authentication on devices they trust' is Disabled (Manual) [10]
CIS 1.5: Ensure that 'Number of methods required to reset' is set to '2' (Manual) [10]
CIS 1.6: Ensure that 'Number of days before users are asked to re-confirm their authentication information' is not set to '0' (Manual) [10]
CIS 1.7: Ensure that 'Notify users on password resets?' is set to 'Yes' (Manual) [10]
CIS 1.8: Ensure that 'Notify all admins when other admins reset their password?' is set to 'Yes' (Manual) [10]
CIS 1.9-1.33: Additional IAM controls covering self-service group management, application registration, custom roles, subscription ownership, security defaults, and privileged identity management [10]
10. MICROSOFT DEFENDER FOR CLOUD (Section 2 - 23 Controls)
CIS 2.1: Ensure that Microsoft Defender for Servers is set to 'On' (Manual) [11]
CIS 2.2: Ensure that Microsoft Defender for App Service is set to 'On' (Manual) [11]
CIS 2.3: Ensure that Microsoft Defender for Azure SQL Databases is set to 'On' (Manual) [11]
CIS 2.4: Ensure that Microsoft Defender for SQL servers on machines is set to 'On' (Manual) [11]
CIS 2.5: Ensure that Microsoft Defender for Storage is set to 'On' (Manual) [11]
CIS 2.6: Ensure that Microsoft Defender for Kubernetes is set to 'On' (Manual) [11]
CIS 2.7: Ensure that Microsoft Defender for Container Registries is set to 'On' (Manual) [11]
CIS 2.8: Ensure that Microsoft Defender for Key Vault is set to 'On' (Manual) [11]
CIS 2.9-2.23: Additional Microsoft Defender controls for DNS, ARM, open-source relational databases, resource manager, auto provisioning, security contacts, and notifications [11]
Summary Statistics
The CIS Azure Foundations Benchmark v1.5.0 contains approximately 147 total controls organized into 10 sections [2]:

Identity and Access Management: 33 controls
Microsoft Defender for Cloud: 23 controls
Storage Accounts: 15 controls
Database Services: 20+ controls (SQL, MySQL, PostgreSQL, Cosmos DB)
Logging and Monitoring: 15+ controls
Networking: 7 controls
Virtual Machines: 7 controls
Key Vault: 8 controls
AppService: 11 controls
Miscellaneous: 1 control