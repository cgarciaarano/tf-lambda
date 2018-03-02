# CI for AWS Lambdas

This project is a PoC of a continuous integration pipeline for AWS lambdas, aiming for:

- Automated testing
- Automated deployment
- Easy rollback 

## Deployment flow

As a prerequisite, we already have the infrastructure in place

In a nutshell, this is the deployment process:

1. The lambda $LATEST is upgraded & tested
2. If we're in the release branch, a new version is published (only if the SHA256 of the upgraded matches with $LATEST)
3. The commit is tagged according to the AWS version
4. The LIVE label is switched to the new version

In case we need to roll back, we just need to change the LIVE label to the previous version


## Sample app

This repository contains a simple application that uses Terraform to create the AWS resources. It just notifies via SNS when a new object is uploaded in a S3 bucket.

So the AWS components used are:

- S3
- Lambda
- SNS

We're going to create different versions of `notify.py` as an example of a development flow.

## Tutorial

### Creating the infrastructure

1. Create the file `creds.auto.tfvars` with the following content:
```
access_key = "YOUR_AWS_KEY"
secret_key = "YOUR_AWS_SECRET"
```
2. Just run `terraform apply` to create the infrastructure

This will create a zip file from the code in `src/`,a lambda function with the code supplied, a lambda alias "LIVE", an S3 bucket, a notification from the S3 bucket when an object is created to the lambda alias, the SNS topic where the notification will be published and all permissions needed.

Check `app.tf` to see the implementation details.

Note that there isn't any version mappend to the lambda yet.

### Testing

To test this PoC, just login to the AWS Console and subscribe to the SNS topic (`upload_notification`) to receive the notification via email. You'll need to confirm your subscription, when it's done, just upload a file to the bucket (`bucket-upload-notification`). You should receive a notification email by the body:

```
Version 1.0 - New file uploaded: s3://bucket-upload-notification/<YOUR FILE>
```

### Deploying new lambda code

Let's change something in the lambda code and deploy it. 

1. Change the version in the message:

```python
message = "version 2.0 - New file uploaded: s3://{bucket}/{file}".format(bucket=bucket, file=key)
```
2. Commit your change and push
```
git commit -a -m "Verbose notification" && git push
```

