import json
import re
import boto3
import os
import logging
from typing import List, Dict

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

def extract_emails(content: str) -> List[str]:
    email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    return list(set(re.findall(email_pattern, content)))


def scan_file(bucket: str, key: str) -> Dict:
    try:
        logger.info(f"Scanning file: {key} in bucket: {bucket}")
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        emails = extract_emails(content)
        
        return {
            'bucket': bucket,
            'file': key,
            'emails': emails,
            'email_count': len(emails)
        }
    except Exception as e:
        logger.error(f"Error scanning file {key} in bucket {bucket}: {str(e)}")
        return {
            'bucket': bucket,
            'file': key,
            'error': str(e)
        }

def scan_bucket(bucket: str) -> List[Dict]:
    try:
        logger.info(f"Processing bucket: {bucket}")
        paginator = s3_client.get_paginator('list_objects_v2')
        results = []
        
        for page in paginator.paginate(Bucket=bucket):
            if 'Contents' not in page:
                continue
            
            for obj in page['Contents']:
                if obj['Size'] > 0:
                    result = scan_file(bucket, obj['Key'])
                    results.append(result)
                    
        return results
    except Exception as e:
        return [{
            'bucket': bucket,
            'error': str(e)
        }]

def lambda_handler(event, context):
    try:
        sns_topic_arn = os.environ['SNS_TOPIC_ARN']
        s3_buckets_list = s3_client.list_buckets()
        buckets = [bucket['Name'] for bucket in s3_buckets_list['Buckets']]
        
        results = []
        for bucket in buckets:
            try:
                results.extend(scan_bucket(bucket))
            except Exception as e:
                logger.error(f"Error processing bucket {bucket}: {str(e)}")
                results.append({
                    'bucket': bucket,
                    'error': str(e)
                })
                
        report = {
            'scan_timestamp': event.get('timestamp', ''),
            'total_buckets': len(buckets),
            'results': results
        }
        
        try:
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Message=json.dumps(report),
                Subject='Labrador S3 Email Scan Results'
            )
            logger.info("Successfully published results to SNS")
        except Exception as e:
            logger.error(f"Error publishing to SNS: {str(e)}")
            raise
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Scan completed successfully',
                'report': report
            })
        }
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
