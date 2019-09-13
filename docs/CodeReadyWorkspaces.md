# Code Ready Workspaces Deployment
For this we are leveraging an existing CRW deployment script from [Agnostid](./Agnosticd.md).

Existing script lives under

```
agnosticd/ansible/roles/ocp-workload-rhte19-optaplanner-101-lab-infra/files/codeready-workspaces-operator-installer/deploy.sh.ocp4`
```
and has been copied to
```
deploy_crw_ocp4.sh
```

In addition we need to copy their CRD from
```
agnosticd/ansible/roles/ocp-workload-rhte19-optaplanner-101-lab-infra/files/codeready-workspaces-operator-installer/custom-resource.yaml
```
to
```
crw-custom-resource.taml
```

Once we've got this baseline we can tweak the scripts to deploy the way we want

