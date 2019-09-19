#!/bin/bash
#

source ./ocp.env
source ./functions

OCP_NAMESPACE=codeready-workspaces

# TODO: 2. Once TODO #1 is completed. Change start-after-create to true.
CRW_API_ENDPOINTS=http://codeready-${OCP_NAMESPACE}.apps.${OCP_DOMAIN}/api/workspace?start-after-create=true


printInfo "Getting an auth token from keyclock in  ${OCP_WORKSPACE}"
AUTH_TOKEN=`curl -s --data "grant_type=password&client_id=codeready-public&username=admin&password=admin" http://keycloak-${OCP_NAMESPACE}.apps.${OCP_DOMAIN}/auth/realms/codeready/protocol/openid-connect/token | jq '.access_token' | sed s/\"//g`

WORKSPACE_SETTINGS='{
  "projects": [
    {
      "problems": [],
      "mixins": [],
      "description": "NodeJS Hello World",
      "source": {
        "location": "https://github.com/che-samples/web-nodejs-sample",
        "type": "git",
        "parameters": {}
      },
      "name": "web-nodejs-simple",
      "type": "node-js",
      "path": "/web-nodejs-simple",
      "attributes": {}
    }
  ],
  "commands": [
    {
      "commandLine": "cd ${current.project.path} \nnode app/app.js",
      "name": "web-nodejs-simple:run",
      "type": "custom",
      "attributes": {
        "goal": "Run",
        "previewUrl": "http://routej95s46ol-codeready-workspaces.apps.cluster-akl-aff2.sandbox335.opentlc.com/"
      }
    }
  ],
  "defaultEnv": "default",
  "name": "bigpharmapi-nodejs-ws",
  "attributes": {},
  "environments": {
    "default": {
      "recipe": {
        "type": "dockerimage",
        "content": "registry.redhat.io/codeready-workspaces/stacks-node"
      },
      "machines": {
        "dev-machine": {
          "servers": {
            "5000/tcp": {
              "protocol": "http",
              "port": "5000",
              "attributes": {}
            },
            "port-8081": {
              "protocol": "http",
              "port": "8081",
              "attributes": {}
            },
            "3000/tcp": {
              "protocol": "http",
              "port": "3000",
              "attributes": {}
            },
            "8080/tcp": {
              "protocol": "http",
              "port": "8080",
              "attributes": {}
            },
            "port-3001": {
              "protocol": "http",
              "port": "3001",
              "attributes": {}
            },
            "9000/tcp": {
              "protocol": "http",
              "port": "9000",
              "attributes": {}
            }
          },
          "volumes": {},
          "installers": [
            "org.eclipse.che.exec",
            "org.eclipse.che.terminal",
            "org.eclipse.che.ws-agent",
            "org.eclipse.che.ls.js-ts",
            "com.redhat.bayesian.lsp"
          ],
          "attributes": {
            "memoryLimitBytes": "2147483648"
          },
          "env": {}
        }
      }
    }
  }
}'

# Handy for debugging
#echo AUTH ${AUTH_TOKEN}
#echo CRW API ENDPOINT "${CRW_API_ENDPOINTS}"

printInfo "Creating Workspace nodejs into namespace ${OCP_NAMESPACE}"
curl -s -X POST --header "Content-Type: application/json" --header "Accept: application/json" --header "Authorization: Bearer ${AUTH_TOKEN}" -d "${WORKSPACE_SETTINGS}" "${CRW_API_ENDPOINTS}"
