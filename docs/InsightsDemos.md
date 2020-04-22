# Insights Demo Setup

This leverages the [RHE8 Demos](./docs/RHEL8Demo.md)  and
RHEL7 Demo instances


## Stage 0 - Validate Environment

Follow steps from [RHE8 Demos](./docs/RHEL8Demo.md)


## Stage 1 - Deploy AWS Instances

```
ansible-playbook rhel8_provision.yaml -e "demo_tag=rhel8insights"

# TBC
#ansible-playbook rhel7_provision.yaml -e "demo_tag=rhel7insights"
```

Add additional SSH Keys
```
ansible-playbook  -i ./hosts ./rhel8_add_keys.yaml
```

Update your hosts file with new host domains and
```
ansible-playbook  -i ./hosts ./rhel_insights.yaml
```

