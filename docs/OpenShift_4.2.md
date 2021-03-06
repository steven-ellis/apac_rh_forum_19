# OpenShift 4.2

Need to test/validate that our demo still works correctly with 
OpenShift 4.2, and ideally with the GA of [OCS 4.2](./OCS_4.2.md).

Baseline installation of installer OpenShift on AWS is covered under
[OpenShift Installer](OpenShiftInstaller.md).

## Version Testing 

- 4.2.1 "OCP and Container Storage for Admins" in RHPDS
    - Using the GA of OCS 4.2.1 on OCP 4.2.7
        - Upgrade OCP to 4.2.13 before deploying the storage operator

- 4.2.1 OpenShift Workshop in RHPDS
    - Using the GA of OCS 4.2.1 on OCP 4.2.13
        - Need to scale up machinesets as we've only got 2 workers to start with
        - No deployment issues as we meet the compatibility matrix for [OCS 4.2](./OCS_4.2.md).
 
- 4.2.0 "OCP and Container Storage for Admins" in RHPDS
    - Using the GA of OCS 4.2.0 on OCP 4.2.7
        - Some deployment issues as we don't meet the compatibility matrix for [OCS 4.2](./OCS_4.2.md).
        - Storage Cluster tab of operator didn't deploy correctly
        - Deployment ultimately works, but some issues
- 4.2.0 Updated "OCP and Container Storage for Admins" Workshop
    - The lab has been updated to GA OCP 4.2.7
        - We can still deploy cleanly using upstream Rook
        - Only issue is we don't have monitoring enabled due to missing operator
        - Operator based OCS deployment includes monitoring as a default
        - Add an additional option to deploy_ocs.sh
- 4.2.0 RHPDS Workshop
    - Using the GA of OCP 4.2
        - Need to scale up machinesets as we've only got 2 workers to start with
        - As we're not using the kubeadmin user issues loading our admin account
        - because this deletes the existing management account we're logged in under
    - OCS 4.2 downstream
        - commit 461a87710078cdd0b96188240f72ae5452835858 (HEAD -> ocs-4.2-rhel-8, origin/ocs-4.2-rhel-8)

- 4.2.0
    - Using the GA of OCP 4.2
    - OCS 4.2 downstream
        - commit 9721d9285fa181d950d4cceeaa9d0ab478a854a7 (HEAD -> ocs-4.2-rhel-8, origin/ocs-4.2-rhel-8)
        - Environment appears to deploy correctly
        - we have CSI pods
        - CephFS PVC deployment works
        - NooBaa stuck in pending waiting on RBD backed storage
        - Ceph RBD backed storage stuck at pending
    - OCS 4.2 Upstream
        - Commit d76c4c137f68d21266ac7fee4cda39a5696add4f (HEAD -> release-4.2, origin/release-4.2)
        - Same NooBaa Issues
- 4.2.0-rc2
    - Ongoing base enironment size issue
        - Tried tweaking instance type in install-config.yaml
    - Rook-Ceph 1.1.0-beta0
        - Deployment of storage fails
    - Rook-Ceph 1.1.2
        - Deployment of storage works
    - OCS 4.2 downstream
        - ocs-4.2-rhel-8 / c9fc0da263cc11984ece432660bad2443d03de95
        - Deployment of OCS 4.2 worked
        - Working NooBaa out of the box
        - test deploy of CephFS using tips from [OCS_4.2.md][./OCS_4.2.md] worked
    - OCS 4.2 downstream
        - ocs-4.2-rhel-8 / 38bbf13c730bf3201d21d6115299f088be2a0a59
        - Issue appears to be that the CSI pods aren't deploying
```
2019-10-08 23:19:46.382969 E | op-cluster: failed to start Ceph csi drivers: failed to load rbdplugin template: failed to load daemonset template. template: rbdplugin:59:32: executing "rbdplugin" at <.RBDGRPCMetricsPort>: can't evaluate field RBDGRPCMetricsPort in type csi.templateParam
```
        - BZ - https://bugzilla.redhat.com/show_bug.cgi?id=1758934
    - OCS 4.2 downstream
        - ocs-4.2-rhel-8 / 5380e5fcb267eedf6951cbd6c1e07bc55159c992
        - Ended up with two OSDs on the same Node
        - NooBaa **won't** complete deployment
        - **Can't create** a sample cephfs pv
- 4.2.0-rc1
    - Ongoing base enironment size issue
    - OCS 4.2 downstream
        - ocs-4.2-rhel-8 / 5380e5fcb267eedf6951cbd6c1e07bc55159c992
        - Ended up with two OSDs on the same Node
        - Means we've got some AZ quorum issue
        - no storage has been allocatedin AZ-c
        - NooBaa **won't** complete deployment
        - **Can't create** a sample cephfs pv
    - OCS 4.2 upstream - 4.2
        - release-4.2 / 16e48adca0e6dc162ab6d33e277680362304013b
        - Also had two OSDs on same Node
        - NooBaa completed deployment
        - Can create a sample cephfs pv
    - 3Scale (2.5) ***Deployed*** - need Balaji to Verify
    - Istio Service Mesh **WORKED**
    - Product Info App **WORKED**
    - BigPharm Fuse App **WORKED**
    - Kubernetes Operators - via Couchbase **WORKED**
    - [Quarkus and Java](./Quarkus.md) **WORKED**
    - Codeready Workspaces](./CodeReadyWorkspaces.md) **WORKED**


- 4.2.0-0.nightly-2019-10-02-150642
    - Potential base enironment size issue
        - Defaults to m4.large instances which are too small
        - to run the majority of our workloads
        - Our existing Workshop instance uses m5.2xlarge workers
    - OCS 4.2 upstream 
        - Some issues with NooBaa's resource requirements
        - Need 4 additional m5.4xlarge instances to run OCS 4.2
    - 3Scale (2.6)
    - Istio Service Mesh
    - Product Info App
    - Kubernetes Operators - via Couchbase -> Hwee Ming
    - [Quarkus and Java](./Quarkus.md)
    - Codeready Workspaces](./CodeReadyWorkspaces.md)
        - Potential **ISSUE**
        - First attempt at deploying failed
        - Might be due to environment size issue above



