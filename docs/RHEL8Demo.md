# RHEL8 Demo Setup

The RHEL 8 demo includes technologies like

* Cockpit


## Pre-requisites
1. Amazon AWS account
2. Ansible installed with boto support
3. Local ansible inventory file - ```hosts```
4. Security Group with SSH (22) and Cockpit (9090) access


## Stage 0 - Validate Environment
Copy `secrets.yaml.sample` to `secrets.yaml` and update with

* your AWS credentials
* [optional] RHN credentials (subject to AMI being used)
    * We are using Activation Keys - https://access.redhat.com/articles/1378093
    * rh_org_id: "UPDATE"
    * rh_org_activationkey: "UPDATE"
* Private Key details for SSH access
* AWS Region
* cockpit_root_pwd in a crypted hash for cockpit access
    * https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#how-do-i-generate-encrypted-passwords-for-the-user-module
* [optional] Route53 ZoneId and domain in secrets.yaml
```
route53_zone: my.domain
HostedZoneId:   DDdOO111kkk222

```


Create / Update ```hosts``` file with and entry for cockpit_demo
```
[cockpit_demo]
<We'll fill in hosts names later>
```

## Stage 1 - Deploy AWS Instance
This takes approx 2 minutes
```
ansible-playbook rhel8_provision.yaml
```

You can provision with a different Demo tag via
```
ansible-playbook rhel8_provision.yaml -e "demo_tag=mytest"
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
ansible-playbook  -i ./hosts ./rhel8_cockpit.yaml
```

# Clean up Deployment
Delete cockpit tagged AWS Instances

```
ansible-playbook ./terminate_cockpit.yaml 
```

or delete instances with a specific "Demo" tag

```
ansible-playbook  ./terminate_cockpit.yaml -e "demo_tag=mytest"
```

## Stage 3 - Add additional ssh-keys for your demo team
The deployment script will use the identity in your secrets.yaml. If you want to add additional
SSH pubkeys to the remote ec2-user you can update your secrets.yaml with
```
ssh_keys_list:
  - "{{ lookup('file', lookup('env','HOME') + '/.ssh/id_rsa.pub') }}"
  - "{{ lookup('file', lookup('env','HOME') + '/.ssh/OCP4.pub') }}"
  - "{{ lookup('file', lookup('env','PWD') + '/.fred.id_rsa.pub') }}"
  - "{{ lookup('file', lookup('env','PWD') + '/.bill.id_rsa.pub') }}"
```
Then run
```
ansible-playbook  -i ./hosts ./rhel8_add_keys.yaml
```
All of your team should now have access over ssh
```
ssh ec2-user@<public-aws-hostname>
```

## Stage 4 - Confirm Cockpit Access
Browse to the url

 - http://<public-aws-hostname\>:9090
