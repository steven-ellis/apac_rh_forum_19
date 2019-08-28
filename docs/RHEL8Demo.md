# RHEL8 Demo Setup

The RHEL 8 demo includes technologies like

* Cockpit


## Pre-requisites
1. Amazon AWS account
2. Ansible installed with boto support


## Stage 0 - Validate Environment
Copy `secrets.env.sample` to `secrets.env` and update with your AWS credentials

## Stage 1 - Deploy AWS Instance
This takes approx 2 minutes
```
ansible-playbook rhel8_provision.yaml -e @./secrets.env
```

## Stage 2 - 

# Clean up Deployment
Delete AWS Instances

