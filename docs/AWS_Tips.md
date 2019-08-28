# AWS Tips

Example commands for interacting with AWS via their command line tool

Reference

* https://docs.aws.amazon.com/cli/latest/userguide/cli-services-ec2-instances.html


## Pre-requisites
1. Amazon AWS account
    * Configured ~/aws/credentials
    * Configured ~/aws/config with AWS Zone
1. Installed aws binary

## Validate Environment
List all currently running instances
```
aws ec2 describe-instances 
```

List tagged instances
```
aws ec2 describe-instances --filters "Name=tag:Name,Values=RHEL8 APAC RH Forum Demo"
```

Shutdown specific instance
```
aws ec2 stop-instances --instance-ids <instance id>
```

