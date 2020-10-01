# OpenShift Cost Management
This is a feature of http://cloud.redhat.com

Deployment requires two operatoris, Cost Management and Metering.


## Refs

- https://access.redhat.com/documentation/en-us/openshift_container_platform/4.4/html/getting_started_with_cost_management/assembly_limiting_access_cost_resources_rbac
- https://access.redhat.com/documentation/en-us/openshift_container_platform/4.4/html-single/metering/index

## Deployment Steps

First deploy your OCP 4.x cluster on currently supported infrasturcure, and enable an appropriate subscription under cloud.redhat.com

Need to make sure

- we have valid AWS credentials
- We have an existing S3 bucket

Using a new bucket appears to fail

First create our namespace - we need to use oc adm as it is a protected name

```
oc adm new-project openshift-metering
oc project openshift-metering
```

Then install the Cost Management Operator via the OpenShift WebUI into the
__openshift-metering__ namespace.

Create our AWS Credential and metering config,
this deployment assumes we're using AWS region __us-east2__

```
oc create secret -n openshift-metering generic my-aws-secret --from-literal=aws-access-key-id=your-access-key  --from-literal=aws-secret-access-key=your-secret-key

oc create -f ocp_demos/metering_config.yaml
```

In this example we're using AWS S3 storage and a hive-metastore-db-data PVC. If you are building a large cluster you
should consider using a MySQL or PostgreSQL backend. We also use the defailt reporting-operator configuration

- https://access.redhat.com/documentation/en-us/openshift_container_platform/4.4/html-single/metering/index#metering-use-mysql-or-postgresql-for-hive_metering-configure-hive-metastore
- https://github.com/kube-reporting/metering-operator/blob/master/Documentation/configuring-reporting-operator.md#openshift-authentication

If you need to debug the setup of the operator adjust the pod name below and monitor the ansible container

```
oc project openshift-metering
oc get pods

oc logs -f metering-operator-9b5d9bbd8-6vrg6 -c ansible
```

Once setup is complete you should see the hive storage PV

```
oc get pv,pvc,sc -n openshift-metering
```

To look at the events occuring using

```
oc get events --sort-by='{.lastTimestamp}' -n openshift-metering
```

If the deployment works correctly we should see some reporting data sources

```
oc get reportdatasources -n openshift-metering | grep -v raw
```
