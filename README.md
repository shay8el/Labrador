# Labrador S3 Email Scanner

This project implements a serverless solution for scanning S3 buckets in AWS to find email addresses in files. The system is designed for low-volume scanning and reporting.

## Architecture

The solution consists of:
- AWS Lambda function for scanning S3 buckets
- SNS Topic for reporting results
- EventBridge rule for scheduling scans
- IAM roles and policies for security

## Prerequisites

- AWS Account with appropriate permissions
- Terraform installed
- Python 3.9 or later
- AWS CLI configured

## Setup Instructions

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Create the Lambda deployment package:
   ```bash
   zip -r lambda_function.zip lambda_function.py
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Deploy the infrastructure:
   ```bash
   terraform apply
   ```

## How it Works

1. The Lambda function runs daily (configurable in `main.tf`)
2. It scans all S3 buckets in the account
3. For each file, it extracts email addresses using regex
4. Results are sent to an SNS topic
5. You can subscribe to the SNS topic to receive the results

## Results Format

The SNS message contains a JSON report with:
- Scan timestamp
- Total number of buckets scanned
- Detailed results for each file, including:
  - Bucket name
  - File name
  - Found email addresses
  - Email count
  - Any errors encountered

## Security Considerations

- The Lambda function has minimal IAM permissions
- Only necessary S3 and SNS permissions are granted
- Results are sent securely via SNS

## Customization

You can modify the following in `main.tf`:
- AWS region
- Scan frequency (currently set to daily)
- Lambda timeout and memory settings
- SNS topic name

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## Notes

- This solution is designed for low-volume scanning
- Large files or high-frequency scanning may require adjustments
