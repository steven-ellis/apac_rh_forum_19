#!/bin/bash
BASE_DIR=$(cd "$(dirname "$0")"; pwd)

DEFAULT_OPENSHIFT_PROJECT="codeready-workspaces"
DEFAULT_ENABLE_OPENSHIFT_OAUTH="false"
DEFAULT_TLS_SUPPORT="false"
DEFAULT_SELF_SIGNED_CERT="true"
DEFAULT_SERVER_IMAGE_NAME="registry.redhat.io/codeready-workspaces/server-rhel8"
DEFAULT_SERVER_IMAGE_TAG="1.2"
DEFAULT_OPERATOR_IMAGE_NAME="registry.redhat.io/codeready-workspaces/server-operator-rhel8:1.2"
DEFAULT_NAMESPACE_CLEANUP="false"

HELP="

How to use this script:
-c,     --cleanup             | cleanup using settings in crw-custom-resource.yaml
-p=,    --project=            | project namespace to deploy CodeReady Workspaces, default: ${DEFAULT_OPENSHIFT_PROJECT}
-o, --oauth                   | enable Log into CodeReady Workspaces with OpenShift credentials, default: ${DEFAULT_ENABLE_OPENSHIFT_OAUTH}
-s,     --secure              | tls support, default: ${DEFAULT_TLS_SUPPORT}
--public-certs                | skip creating a secret with OpenShift router cert, default: false, which means operator will auto fetch router cert
--operator-image=             | operator image, default: ${DEFAULT_OPERATOR_IMAGE_NAME}
--server-image=               | server image, default: ${DEFAULT_SERVER_IMAGE_NAME}
-v=, --version=               | server image tag, default: ${DEFAULT_SERVER_IMAGE_TAG}
--verbose                     | stream deployment logs to console, default: false
-h,     --help                | show this help menu
"
if [[ $# -eq 0 ]] ; then
  echo -e "$HELP"
  exit 0
fi
for key in "$@"
do
  case $key in
    --verbose)
      FOLLOW_LOGS="true"
      shift
      ;;
    --public-certs)
      SELF_SIGNED_CERT="false"
      shift
      ;;
    -o| --oauth)
      ENABLE_OPENSHIFT_OAUTH="true"
      shift
      ;;
    -s| --secure)
      TLS_SUPPORT="true"
      shift
      ;;
    -p=*| --project=*)
      OPENSHIFT_PROJECT="${key#*=}"
      shift
      ;;
    --operator-image=*)
      OPERATOR_IMAGE_NAME=$(echo "${key#*=}")
      shift
      ;;
    --server-image=*)
      SERVER_IMAGE_NAME=$(echo "${key#*=}")
      shift
      ;;
    -v=*|--version=*)
      SERVER_IMAGE_TAG=$(echo "${key#*=}")
      shift
      ;;
    -c | --cleanup)
      CLEANUP=true
      ;;
    -h | --help)
      echo -e "$HELP"
      exit 1
      ;;
    *)
      echo "Unknown argument passed: '$key'."
      echo -e "$HELP"
      exit 1
      ;;
  esac
done

export TERM=xterm

export TLS_SUPPORT=${TLS_SUPPORT:-${DEFAULT_TLS_SUPPORT}}

export SELF_SIGNED_CERT=${SELF_SIGNED_CERT:-${DEFAULT_SELF_SIGNED_CERT}}

export OPENSHIFT_PROJECT=${OPENSHIFT_PROJECT:-${DEFAULT_OPENSHIFT_PROJECT}}

export ENABLE_OPENSHIFT_OAUTH=${ENABLE_OPENSHIFT_OAUTH:-${DEFAULT_ENABLE_OPENSHIFT_OAUTH}}

export SERVER_IMAGE_NAME=${SERVER_IMAGE_NAME:-${DEFAULT_SERVER_IMAGE_NAME}}

export SERVER_IMAGE_TAG=${SERVER_IMAGE_TAG:-${DEFAULT_SERVER_IMAGE_TAG}}

export OPERATOR_IMAGE_NAME=${OPERATOR_IMAGE_NAME:-${DEFAULT_OPERATOR_IMAGE_NAME}}

DEFAULT_NO_NEW_NAMESPACE="false"
export NO_NEW_NAMESPACE=${NO_NEW_NAMESPACE:-${DEFAULT_NO_NEW_NAMESPACE}}

export NAMESPACE_CLEANUP=${NAMESPACE_CLEANUP:-${DEFAULT_NAMESPACE_CLEANUP}}

printInfo() {
  green=`tput setaf 2`
  reset=`tput sgr0`
  echo "${green}[INFO]: ${1} ${reset}"
}

printWarning() {
  yellow=`tput setaf 3`
  reset=`tput sgr0`
  echo "${yellow}[WARNING]: ${1} ${reset}"
}

printError() {
  red=`tput setaf 1`
  reset=`tput sgr0`
  echo "${red}[ERROR]: ${1} ${reset}"
}

preReqs() {
  printInfo "Welcome to CodeReady Workspaces Installer"
  if [ -x "$(command -v oc)" ]; then
    printInfo "Found oc client in PATH"
    export OC_BINARY="oc"
  elif [[ -f "/tmp/oc" ]]; then
    printInfo "Using oc client from a tmp location"
    export OC_BINARY="/tmp/oc"
  else
    printError "Command line tool ${OC_BINARY} (https://docs.openshift.org/latest/cli_reference/get_started_cli.html) not found. Download oc client and add it to your \$PATH."
    exit 1
  fi
}

# check if ${OC_BINARY} client has an active session
isLoggedIn() {
  printInfo "Checking if you are currently logged in..."
  ${OC_BINARY} whoami > /dev/null
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printError "Log in to your OpenShift cluster: ${OC_BINARY} login --server=yourServer"
    exit 1
  else
    CONTEXT=$(${OC_BINARY} whoami -c)
    printInfo "Active session found. Your current context is: ${CONTEXT}"
      ${OC_BINARY} get customresourcedefinitions > /dev/null 2>&1
      OUT=$?
      if [ ${OUT} -ne 0 ]; then
        printWarning "Creation of a CRD and RBAC rules requires cluster-admin privileges. Login in as user with cluster-admin role"
        printWarning "The installer will continue, however deployment is likely to fail"
    fi
  fi
}

checkCRD() {

  ${OC_BINARY} get customresourcedefinitions/checlusters.org.eclipse.che > /dev/null 2>&1
  OUT=$?
  if [ ${OUT} -ne 0 ]; then
    printInfo "Creating custom resource definition"
    createCRD > /dev/null
  else
    printInfo "Custom resource definition already exists"
  fi
}

createCRD() {
  printInfo "Creating custom resource definition"
  ${OC_BINARY} apply -f - <<EOF  > /dev/null
  apiVersion: apiextensions.k8s.io/v1beta1
  kind: CustomResourceDefinition
  metadata:
    name: checlusters.org.eclipse.che
  spec:
    group: org.eclipse.che
    names:
      kind: CheCluster
      listKind: CheClusterList
      plural: checlusters
      singular: checluster
    scope: Namespaced
    version: v1
    subresources:
      status: {}
EOF

OUT=$?
if [ ${OUT} -ne 0 ]; then
  printWarning "Failed to create custom resource definition. Current user does not have privileges to list and create CRDs"
  printWarning "Ask your cluster admin to register a CheCluster CRD:"
  cat <<EOF
  apiVersion: apiextensions.k8s.io/v1beta1
  kind: CustomResourceDefinition
  metadata:
    name: checlusters.org.eclipse.che
  spec:
    group: org.eclipse.che
    names:
      kind: CheCluster
      listKind: CheClusterList
      plural: checlusters
      singular: checluster
    scope: Namespaced
    version: v1
    subresources:
      status: {}
EOF
fi
}


deleteCustomResource() {
  printInfo "Deleteing Custom resource checlusters/codeready from  ${OPENSHIFT_PROJECT}"
  ${OC_BINARY} delete checlusters/codeready -n ${OPENSHIFT_PROJECT}
}

if [ "${CLEANUP}" = true ] ; then
  preReqs
  isLoggedIn
  deleteCustomResource
  oc delete project ${OPENSHIFT_PROJECT}
fi
