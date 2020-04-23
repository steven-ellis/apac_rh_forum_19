# Insights Demo Setup

This leverages the [RHE8 Demos](./docs/RHEL8Demo.md)  and
RHEL7 Demo instances


## Stage 0 - Validate Environment

Follow pre-requiste steps from Stage 0 under [RHE8 Demos](./docs/RHEL8Demo.md)


## Stage 1 - Deploy AWS Instances

```
ansible-playbook rhel8_provision.yaml -e "demo_tag=rhel8insights"

ansible-playbook rhel7_provision.yaml -e "demo_tag=rhel7insights"
ansible-playbook rhel7_provision.yaml -e "demo_tag=rhel7openscap"
ansible-playbook rhel7_provision.yaml -e "demo_tag=rhel7demo"
```

Update your hosts file with new host instances we've just provisioned
under the group
```
[insights_demo]

```

Add additional SSH Keys for your team
```
ansible-playbook  -i ./hosts ./rhel8_add_keys.yaml
```

Enable Insights
```
ansible-playbook  -i ./hosts ./rhel_insights.yaml
```

## Cleanup Environment
We can delete the instances via

```
ansible-playbook  ./terminate_cockpit.yaml -e "demo_tag=rhel8insights"
ansible-playbook  ./terminate_cockpit.yaml -e "demo_tag=rhel7insights"
ansible-playbook  ./terminate_cockpit.yaml -e "demo_tag=rhel7openscap"
ansible-playbook  ./terminate_cockpit.yaml -e "demo_tag=rhel7demo"
```
