# GovGrasp Security & Threat Modeling (STRIDE)

## 1. STRIDE Analysis Matrix

| Category | Threat | Impact | Mitigation Strategy (AWS/DevSecOps) |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Impersonating the Laravel API to trigger the Python Worker. | High | Use IAM Roles for ECS and Private VPC Security Groups. |
| **Tampering** | Unauthorized modification of OCDS JSON data stored in S3. | Medium | Enable S3 Object Lock and Versioning; restrict access via IAM. |
| **Repudiation** | An admin claims they didn't trigger a mass data fetch. | Low | Enable AWS CloudTrail for API audit logs. |
| **Information Disclosure** | Leakage of AWS Keys or LLM tokens via source code. | Critical | Mandatory use of AWS Secrets Manager; Pre-commit hooks (TruffleHog). |
| **Denial of Service** | Flooding the Laravel API to prevent tender analysis. | High | Implement AWS WAF with Geo-blocking and Rate-Limiting. |
| **Elevation of Privilege** | PHP container gaining access to RDS root credentials. | High | IAM Least Privilege: Task Execution Roles specific to each service. |

## 2. Secure Authentication Flow

The **Open Claw Agent** (Python) is an internal service. It is NOT exposed via a Public IP. 

1. **Trigger:** The React frontend sends a request to the Laravel API (Authenticated via OAuth2/Sanctum).
2. **Authorization:** Laravel checks user permissions in the RDS database.
3. **Execution:** Laravel uses the AWS SDK (authorized by an IAM Role) to invoke the ECS Fargate Task for Python.
4. **Secrets:** Both services pull dynamic credentials from **AWS Secrets Manager** at runtime.

## 3. DevOpsSec Pipeline Integration

- **SAST:** Bandit (Python) and PHPStan (PHP) integrated into GitHub Actions.
- **Dependency Scanning:** Dependabot enabled to check for vulnerable libraries.
- **Infrastructure Scan:** TFLint or Checkov to validate Terraform/CDP security before deployment.