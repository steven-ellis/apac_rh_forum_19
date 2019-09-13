#!/bin/bash
#

source ./ocp.env
source ./functions

OCP_NAMESPACE=codeready-workspaces

# TODO: 1. Change the CRW API endpoints to dynamic.
# TODO: 2. Once TODO #1 is completed. Change start-after-create to true.
CRW_API_ENDPOINTS=http://codeready-codeready-workspaces.apps.cluster-akl-aff2.sandbox335.opentlc.com/api/workspace?start-after-create=false

AUTH_TOKEN=`curl --data "grant_type=password&client_id=codeready-public&username=admin&password=redhatdemo" http://keycloak-codeready-workspaces.apps.cluster-akl-aff2.sandbox335.opentlc.com/auth/realms/codeready/protocol/openid-connect/token | jq '.access_token' | sed s/\"//g`

WORKSPACE_SETTINGS='{
  "defaultEnv": "default",
  "environments": {
    "default": {
      "machines": {
        "dev-machine": {
          "attributes": {
            "memoryLimitBytes": "5368709120"
          },
          "servers": {
            "5005/tcp": {
              "port": "5005",
              "attributes": {},
              "protocol": "http"
            },
            "8080/tcp": {
              "port": "8080",
              "attributes": {},
              "protocol": "http"
            },
            "8000/tcp": {
              "port": "8000",
              "attributes": {},
              "protocol": "http"
            }
          },
          "volumes": {},
          "installers": [
            "org.eclipse.che.exec",
            "org.eclipse.che.terminal",
            "org.eclipse.che.ws-agent",
            "org.eclipse.che.ls.java",
            "com.redhat.bayesian.lsp"
          ],
          "env": {}
        }
      },
      "recipe": {
        "type": "dockerimage",
        "content": "image-registry.openshift-image-registry.svc:5000/openshift/quarkus-stack:1.0"
      }
    }
  },
  "projects": [
    {
      "name": "quarkus-todo-app",
      "attributes": {
        "contribute_to_branch": [
          "master"
        ]
      },
      "type": "blank",
      "source": {
        "location": "https://github.com/jumperwire/quarkus-todo-app.git",
        "type": "git",
        "parameters": {}
      },
      "path": "/quarkus-todo-app",
      "description": "",
      "problems": [],
      "mixins": [
        "pullrequest"
      ]
    }
  ],
  "name": "quarkus-workspace",
  "attributes": {},
  "commands": [
    {
      "commandLine": "mvn clean compile quarkus:dev -f ${current.project.path}",
      "name": "Start Live Coding",
      "attributes": {
        "goal": "Run",
        "previewUrl": "${server.8080/tcp}"
      },
      "type": "custom"
    },
    {
      "commandLine": "${HOME}/stack-analysis.sh -f ${current.project.path}/pom.xml -p ${current.project.path}",
      "name": "dependency_analysis",
      "attributes": {
        "goal": "Run",
        "previewUrl": ""
      },
      "type": "custom"
    },
    {
      "commandLine": "MAVEN_OPTS=\"-Xmx1024M -Xss128M -XX:MetaspaceSize=512M -XX:MaxMetaspaceSize=1024M -XX:+CMSClassUnloadingEnabled\" mvn -f ${current.project.path} clean package -Pnative -DskipTests",
      "name": "Build Native Quarkus App",
      "attributes": {
        "goal": "Package",
        "previewUrl": ""
      },
      "type": "custom"
    },
    {
      "commandLine": "MAVEN_OPTS=\"-Xmx1024M -Xss128M -XX:MetaspaceSize=512M -XX:MaxMetaspaceSize=1024M -XX:+CMSClassUnloadingEnabled\" mvn -f ${current.project.path} clean package -DskipTests",
      "name": "Create Executable JAR",
      "attributes": {
        "goal": "Package",
        "previewUrl": ""
      },
      "type": "custom"
    },
    {
      "commandLine": "mvn verify -f ${current.project.path}",
      "name": "Run Quarkus Tests",
      "attributes": {
        "goal": "Test",
        "previewUrl": ""
      },
      "type": "mvn"
    },
    {
      "commandLine": "mvn clean compile quarkus:dev -Ddebug -f ${current.project.path}",
      "name": "Debug Quarkus App",
      "attributes": {
        "goal": "Debug",
        "previewUrl": "${server.8080/tcp}"
      },
      "type": "custom"
    }
  ]
}'

curl -X POST --header "Content-Type: application/json" --header "Accept: application/json" --header "Authorization: Bearer ${AUTH_TOKEN}" -d "${WORKSPACE_SETTINGS}" "${CRW_API_ENDPOINTS}"
