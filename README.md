# S3 Access Point Policy Management

Demonstrates how to use S3 Access Points to grant granular, prefix-based access to S3 buckets without modifying the main bucket policy.

## Security Model: Multi-Layer Access Control

This implementation uses a **defense-in-depth approach** with three policy layers:

### 1. IAM Policy (Identity-Based)
Grants S3 capabilities to the role:
```
✓ Allows s3:ListBucket and s3:GetObject on bucket and access point ARNs
```

### 2. Bucket Policy (Resource-Based)
Forces access path separation:
```
✓ Admins → Direct bucket access (s3://bucket-name/)
✗ Non-admins → DENIED direct access (must use access points)
✓ Everyone → Allowed via access points
```

### 3. Access Point Policy (Resource-Based)
Enforces granular restrictions:
```
✓ Only specific role allowed (StringNotEquals on aws:PrincipalArn)
✗ Write operations denied (read-only)
✓ ListBucket only for s3accesslogs/ prefix
✓ GetObject only for s3accesslogs/* objects
```

### How It Works Together

**Admin access (SSO roles)**:
- Direct bucket access → Bucket policy allows → Full access

**Application access (foo-via-access-point role)**:
- Direct bucket access → Bucket policy DENIES → Access denied
- Via access point → Bucket policy allows → Access point policy evaluates → Restricted to s3accesslogs/ prefix, read-only

This ensures **non-admin access is channeled through access points** where fine-grained controls are applied.

## Benefits

- **Isolation**: Changes to access point policies don't affect bucket policy or other access points
- **Scalability**: Bypass bucket policy 20KB size limit by distributing logic across access points
- **Delegation**: Teams manage their own access point policies without bucket policy permissions
- **Auditability**: Clear separation between admin (direct) and application (access point) access patterns

## AWS CLI Usage Examples

### 1. Get the Access Point Alias

```bash
# Get the alias from S3 Control API
AP_ALIAS=$(aws s3control get-access-point \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --name s3-check-role-2025-ap \
  --query Alias --output text)
echo $AP_ALIAS
# Output: s3-check-role-2025-a-qhfkiis7tjte69sfoj59rz6545geqeuw2b-s3alias

# Alternative: Get from SSM Parameter Store
AP_ALIAS=$(aws ssm get-parameter --name /s3-access-point/s3-check-role-2025/alias --query Parameter.Value --output text)

# Alternative: Using Terraform output
AP_ALIAS=$(terraform output -raw secure_bucket_access_point_alias)
```

### 2. Assume the Role

```bash
# Export credentials for the allowed role
make export-creds

# Set the credentials file
export AWS_SHARED_CREDENTIALS_FILE=$PWD/aptest-test-consume-credentials
```

### 3. Access Patterns

#### ❌ Listing top-level objects (blocked)

```bash
# Try to list the entire access point - DENIED
aws s3 ls s3://$AP_ALIAS/
# Error: An error occurred (AccessDenied) when calling the ListObjectsV2 operation

# Try to list bar/ prefix - DENIED
aws s3 ls s3://$AP_ALIAS/bar/
# Error: An error occurred (AccessDenied) when calling the ListObjectsV2 operation
```

#### ✅ Listing allowed prefix (permitted)

```bash
# List objects in s3accesslogs/ prefix - ALLOWED
aws s3 ls s3://$AP_ALIAS/s3accesslogs/
# Output: 2025-10-06 19:05:23          45 test.txt

# Get object from s3accesslogs/ prefix - ALLOWED
aws s3 cp s3://$AP_ALIAS/s3accesslogs/test.txt -
# Output: This is a test file in s3accesslogs prefix - 2025-10-06
```

#### ❌ Write operations (blocked)

```bash
# Try to write to allowed prefix - DENIED
echo "test" | aws s3 cp - s3://$AP_ALIAS/s3accesslogs/new.txt
# Error: An error occurred (AccessDenied) when calling the PutObject operation
```

### 4. Direct Bucket Access (blocked)

Even with the role, direct bucket access is blocked by the bucket policy:

```bash
# Try to access bucket directly - DENIED
aws s3 ls s3://s3-check-role-2025/
# Error: An error occurred (AccessDenied) when calling the ListObjectsV2 operation

# Access must go through the access point
aws s3 ls s3://$AP_ALIAS/s3accesslogs/
# Success!
```

## Bucket Policy Logic (Access Path Enforcement)

The bucket policy uses a single **Deny statement with AND conditions** to enforce access path separation:

```
Deny IF (NOT admin) AND (NOT via access point from this account)
```

This creates two allowed paths:

### Path 1: Admin Direct Access
```
✓ Admin role → Direct bucket (s3://bucket/) → Allowed
✓ Admin role → Via access point → Allowed (but unnecessary)
```

### Path 2: Non-Admin via Access Point
```
✗ Non-admin role → Direct bucket → DENIED by bucket policy
✓ Non-admin role → Via access point → Allowed by bucket policy
                                    → Access point policy evaluates
                                    → Restricted to s3accesslogs/ prefix
```

**Key Insight**: The bucket policy doesn't enforce prefix restrictions—it only ensures non-admins use access points. The **access point policy** provides the actual data access controls (prefix, read-only, specific roles).

## References

- [AWS Blog: Restrict S3 Bucket Access to Specific IAM Roles](https://aws.amazon.com/blogs/security/how-to-restrict-amazon-s3-bucket-access-to-a-specific-iam-role/)
- [AWS Docs: Access Points](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points.html)
- [AWS Docs: Bucket Policy Examples](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html)