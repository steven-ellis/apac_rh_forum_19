# Quarkus and Java Demo

This demo is designed to show off how lightweight and scalable Quarkus
is in comparison to a traditional Java container

The deployment configs for the demo are hosted under

- https://github.com/jumperwire/supersonic-subatomic-java

Deployment of the demo and resource scaling is all managed under

* [quarkus.sh](../quarkus.sh)


## Pre-requisites
This is part of our overall [OpenShift Demo](OpenShiftDemo.md) and needs to have
additional tagged worker nodes to host the quarkus and java applications.

```
# Create additional machine-sets for quarkus and java
./scale_workers.sh quarkus
./scale_workers.sh java

# Start the new machines and monitor their creation
./scale_workers.sh start
./scale_workers.sh status

# When finishe clean up the environment to save on resources
./scale_workers.sh stop
./scale_workers.sh status
```

## Deploying / Removing Demo

```
# Deployment
./quarkus.sh setup

# Removal
./quarkus.sh cleanup
```

## Scaling the Demo

```
# Scale all workloads to 100
./quarkus.sh scale_up

# Scale both workloads to N instances
./quarkus.sh scale N

# Scale both workloads back to 1 instance
./quarkus.sh scale_down

# Check on current replica set
./quarkus.sh status

# Watch the replica set  
./quarkus.sh watch

```
