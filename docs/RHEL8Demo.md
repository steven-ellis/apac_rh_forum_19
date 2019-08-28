# RHEL8 Demo Setup

The RHEL 8 demo includes technologies like

* Cockpit


## Pre-requisites
1. Amazon AWS account
2. Ansible installed with boto support
3. Local ansible inventory file - ```hosts```
3. Security Group with SSH (22) and Cockpit (9090) access


## Stage 0 - Validate Environment
Copy `secrets.yaml.sample` to `secrets.yaml` and update with

* your AWS credentials
* [optional] RHN credentials (subject to AMI being used)
* Private Key details for SSH access
* AWS Region
* cockpit_root_pwd in a crypted hash for cockpit acces
    * https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#how-do-i-generate-encrypted-passwords-for-the-user-module



Create / Update ```hosts``` file with and entry for cockpit_demo
```
[cockpit_demo]
<We'll fill in hosts names later>
```

## Stage 1 - Deploy AWS Instance
This takes approx 2 minutes
```
ansible-playbook rhel8_provision.yaml -e @./secrets.yaml
```

You can provision with a different Demo tag via
```
ansible-playbook rhel8_provision.yaml -e @./secrets.yaml -e "demo_tag=mytest"
```

## Stage 2 - Install Demo Requirements
The deployment script will return with the public address details of your new RHEL8 instance
```
"Deployed Instance: ec2-18-99-33-255.us-east-2.compute.amazonaws.com available over SSH"
```

Add this public name to the ```hosts``` file for our [cockpit_demo] group
```
[cockpit_demo]
ec2-AAA-BBB-CCC-DDD.us-east-2.compute.amazonaws.com
```

Deploy the Cockpit requirements
```
ansible-playbook  -i ./hosts ./rhel8_cockpit.yaml  -e @./secrets.yaml
```

# Clean up Deployment
Delete cockpit tagged AWS Instances

```
ansible-playbook  -e @secrets.yaml ./terminate_cockpit.yaml 
```

or delete instances with a specific "Demo" tag

ansible-playbook  -e @secrets.yaml ./terminate_cockpit.yaml -e "demo_tag=mytest"

