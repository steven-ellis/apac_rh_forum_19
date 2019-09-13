# Code Ready Workspaces Deployment
For this we are leveraging an existing CRW deployment script from [Agnostid](./Agnosticd.md).

## Deploying CRW

Make sure we're logged in correctly to our OpenShift instance,
and we have csi-cephfs and rook-ceph-block storage classes
```
./setup.sh
oc get sc
```
Output should look similar to
```
NAME                        PROVISIONER                     AGE
csi-cephfs                  rook-ceph.cephfs.csi.ceph.com   44h
gp2                         kubernetes.io/aws-ebs           2d
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com      44h
```

Deploy CRW Operator into the required namespace/project
```
./deploy_crw_ocp4.sh -d -p=<namespace>
```

The process should take approximately 5-10 minutes

We then import the Quarkus image we need for our workspace
```
./crw_imagestream.sh
```

Then create a quarkus workspace
```
./crw_create_quarkus_workspace.sh
```

## Deployment Scripts Reference
Existing upstream script lives under

```
agnosticd/ansible/roles/ocp-workload-rhte19-optaplanner-101-lab-infra/files/codeready-workspaces-operator-installer/deploy.sh.ocp4`
```
and has been copied to - ```deploy_crw_ocp4.sh```

In addition we need to copy their CRD from
```
agnosticd/ansible/roles/ocp-workload-rhte19-optaplanner-101-lab-infra/files/codeready-workspaces-operator-installer/custom-resource.yaml
```
to - ```crw-custom-resource.yaml```

Once we've got this baseline we can tweak the scripts to deploy the way we want

## Configure CHE Config Map
We need to do this so we pickup the correct storage
```
CHE_INFRA_KUBERNETES_PVC_STORAGE__CLASS__NAME: "csi-cephfs"
```

To check the current config map
```
oc get configmap che -o yaml -n crw
```

Upstream Reference
 * https://github.com/eclipse/che-operator/blob/master/deploy/crds/org_v1_che_cr.yaml

We simply need to update our ```crw-custom-resource.yaml``` with 
```
    storage:
      pvcStrategy: 'per-workspace'
      pvcClaimSize: 1Gi
      # keep blank unless you need to use a non default storage class for Postgres PVC
      postgresPVCStorageClassName: ''
      # keep blank unless you need to use a non default storage class for workspace PVC(s)
      workspacePVCStorageClassName: 'csi-cephfs'
```
