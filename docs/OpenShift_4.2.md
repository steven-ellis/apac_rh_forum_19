# OpenShift 4.2

Need to test/validate that our demo still works correctly with 
OpenShift 4.2, and ideally with the GA of OCS 4.2

## Version Testing 

- 4.2.0-0.nightly-2019-10-02-150642
    - Potential base enironment size issue
        - Defaults to m4.large instances which are too small
        - to run the majority of our workloads
        - Out existing Workshop instance uses m5.2xlarge workers
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



