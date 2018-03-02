#!/usr/bin/env python
import boto3
import os
import json


def handler(event, context):
    client = boto3.client('sns')
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        message = "version 2 - New file uploaded: s3://{bucket}/{file}".format(bucket=bucket, file=key)
        response = client.publish(
            TopicArn=os.environ['SNS_TOPIC'],
            Message=json.dumps({'default': message}),
            MessageStructure='json'
        )
