#!/bin/bash

# Creates a Kubernetes secret for Docker credentials in the format required by
# Artifactory.

usage() {
	echo "$0: <username> <email> <artifactory_registry> <k8s_namespace>"
	exit
}

if [[ -z "$1" ]]; then usage; fi
export USERNAME="$1"
shift
if [[ -z "$1" ]]; then usage; fi
export EMAIL="$1"
shift
if [[ -z "$1" ]]; then usage; fi
export ARTIFACTORY_REGISTRY="$1"
shift
if [[ -z "$1" ]]; then usage; fi
export K8S_NAMESPACE="$1"
shift

echo "Creating artifactorycreds in context: $(kubectl config current-context)"
read -p "Is this correct? [Y/n] " answer
echo
if [[ -z $answer ]] || [[ $answer = "Y" ]] || [[ $answer = "y" ]]; then
	:
else
	exit
fi

read -s -p "Enter your password: " PASSWORD
echo
PASSWORD=$PASSWORD jq -r --null-input '{ "auths": { (env.ARTIFACTORY_REGISTRY): { "Username": env.USERNAME, "Password": env.PASSWORD, "Email": env.EMAIL } } } | @base64' > dockerconfigjson
echo "Creating docker config secret as:"
base64 --decode < dockerconfigjson 2>/dev/null | jq '.auths[env.ARTIFACTORY_REGISTRY].Password = "<password>"'

echo "---
apiVersion: v1
data:
  .dockerconfigjson: $(cat dockerconfigjson)
kind: Secret
metadata:
  name: artifactorycreds
  namespace: $K8S_NAMESPACE
type: kubernetes.io/dockerconfigjson" | kubectl apply -f -

rm dockerconfigjson
