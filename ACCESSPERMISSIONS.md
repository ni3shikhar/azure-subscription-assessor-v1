Based on industry best practices for performing CIS Azure Foundations Benchmark assessments with least privilege access, here are the required Azure permissions:
Azure Permissions for CIS Benchmark Assessment (Least Privilege)
1. AZURE AD / MICROSOFT ENTRA ID LEVEL
Primary Role
Global Reader (Recommended) [1]

Provides read-only access to all Azure AD administrative features
Can view all configuration settings, users, groups, and policies
Cannot make any changes

Alternative: Security Reader (more limited scope)
Microsoft Graph API Permissions (Application Permissions)
For service principal/app registration access [2]:

Application.Read.All - Read all applications
Group.Read.All - Read all groups
RoleManagement.Read.Directory - Read role management data
User.Read.All - Read all users' full profiles
Directory.Read.All - Read directory data
Policy.Read.All - Read organization policies
Organization.Read.All - Read organization information

2. AZURE SUBSCRIPTION LEVEL
Built-in Roles (Choose One Approach)
Option A: Using Built-in Roles (Recommended for Simplicity)
Reader role at Subscription scope PLUS additional specific permissions:

Base permissions: Read all resources
Limitation: Cannot read some security-specific configurations

Security Reader role at Subscription scope [3]:

View Microsoft Defender for Cloud recommendations
View security alerts
View security policies
View security states
Cannot make changes

Monitoring Reader role at Subscription scope [4]:

View all monitoring data
View diagnostic settings
View activity logs
View metrics

Option B: Custom RBAC Role (Recommended for Strictest Least Privilege)
Create a custom role with these specific actions [2]:
json{
  "Name": "CIS Benchmark Auditor",
  "Description": "Read-only access for CIS benchmark assessment",
  "Actions": [
    "*/read",
    "Microsoft.Authorization/*/read",
    "Microsoft.Authorization/policyAssignments/read",
    "Microsoft.Authorization/policyDefinitions/read",
    "Microsoft.Authorization/policySetDefinitions/read",
    "Microsoft.Authorization/roleAssignments/read",
    "Microsoft.Authorization/roleDefinitions/read",
    "Microsoft.Insights/alertRules/read",
    "Microsoft.Insights/diagnosticSettings/read",
    "Microsoft.Insights/logDefinitions/read",
    "Microsoft.Insights/metrics/read",
    "Microsoft.Insights/metricDefinitions/read",
    "Microsoft.Management/managementGroups/read",
    "Microsoft.Network/*/read",
    "Microsoft.Network/networkSecurityGroups/read",
    "Microsoft.Network/networkWatchers/read",
    "Microsoft.OperationalInsights/workspaces/*/read",
    "Microsoft.Resources/deployments/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Resources/subscriptions/read",
    "Microsoft.Security/*/read",
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/listkeys/action",
    "Microsoft.Sql/servers/read",
    "Microsoft.Sql/servers/databases/read",
    "Microsoft.Sql/servers/auditingSettings/read",
    "Microsoft.Sql/servers/securityAlertPolicies/read",
    "Microsoft.Compute/*/read",
    "Microsoft.Web/sites/read",
    "Microsoft.Web/sites/config/list/action"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
3. KEY VAULT SPECIFIC PERMISSIONS
For Vaults using Access Policy Model
Grant these permissions to the service principal for each Key Vault [2]:
Key Permissions:

Get
List

Secret Permissions:

Get
List

Certificate Permissions:

Get
List

For Vaults using Azure RBAC Model
Assign these roles at Key Vault scope:

Key Vault Reader - Control plane read access
Key Vault Secrets User - Read secrets (if needed)
Key Vault Certificates User - Read certificates (if needed)
Key Vault Crypto User - Read keys (if needed)

4. STORAGE ACCOUNT PERMISSIONS
Storage Blob Data Reader (for reading storage logs and configurations) [5]:

Read blob containers and blobs
Read storage account diagnostic logs

Storage Queue Data Reader (for queue logging assessment):

Read queue messages and metadata

Storage File Data SMB Share Reader (for file share assessment):

Read file shares over SMB

5. NETWORK WATCHER PERMISSIONS
Network Contributor (read-only subset) or specific permissions:

Microsoft.Network/networkWatchers/read
Microsoft.Network/networkWatchers/queryFlowLogStatus/action
Microsoft.Network/networkWatchers/securityGroupView/action

6. LOG ANALYTICS WORKSPACE PERMISSIONS
Log Analytics Reader:

Microsoft.OperationalInsights/workspaces/*/read
Microsoft.OperationalInsights/workspaces/query/read
Access to query logs and view workspace data

7. SUMMARY: MINIMUM PERMISSION SET
For a complete CIS Azure Foundations Benchmark assessment, assign:
At Tenant/Azure AD Level:

Global Reader role
OR
Service Principal with Microsoft Graph API permissions listed above

At Subscription Level:

Reader role (built-in)
Security Reader role (built-in)
Monitoring Reader role (built-in)
OR
Custom "CIS Benchmark Auditor" role with permissions listed above

At Resource Level:

Key Vault Reader on all Key Vaults
Key Vault access policies (Get, List for Keys, Secrets, Certificates) if using access policy model
Storage Blob Data Reader on storage accounts with logs
Log Analytics Reader on Log Analytics workspaces

8. IMPLEMENTATION APPROACH
Using Service Principal (Recommended):

Create an App Registration in Azure AD
Grant Microsoft Graph API permissions (listed above)
Grant Admin Consent for the API permissions
Assign Azure RBAC roles at subscription/resource group level
Add Key Vault access policies for each vault

Using User Account:

Assign user the Global Reader role in Azure AD [1]
Assign user the combination of Reader, Security Reader, and Monitoring Reader roles at subscription level
Add user to Key Vault access policies

9. VALIDATION CHECKLIST
Ensure the assessment account can:

✓ Read Azure AD users, groups, and policies
✓ Read MFA status and authentication methods
✓ Read Azure Policy assignments and definitions
✓ Read Microsoft Defender for Cloud settings
✓ Read Storage Account configurations and network rules
✓ Read SQL Database auditing and encryption settings
✓ Read Network Security Groups and flow logs
✓ Read Key Vault keys, secrets, and certificate metadata
✓ Read Virtual Machine configurations and extensions
✓ Read App Service configurations
✓ Read diagnostic settings and activity logs
✓ Read monitoring alerts and log analytics

10. IMPORTANT NOTES

Read-Only Access: All permissions listed are read-only and follow least privilege principles [1]
No Write Operations: The assessment account cannot modify any resources or configurations
Storage Account Keys: ListKeys action is required only for reading diagnostic log storage account configurations, not for general storage access [4]
Multiple Key Vaults: Access policies must be configured individually for each Key Vault if using the access policy model [2]
Subscription-wide Scope: Most roles should be assigned at the subscription level to assess all resources