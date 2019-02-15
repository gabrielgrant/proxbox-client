#! /bin/bash

kubectl create -f https://raw.githubusercontent.com/gabrielgrant/proxbox-client/master/kubernetes-manifest.yaml

POD_NAME=`kubectl get pod --output=json | jq -r '.items[] | select(.metadata.name|startswith("proxbox-client")).metadata.name'`  #  -r flag is needed to not get quotes in the output

# wait until houdini is up
until timeout 10s kubectl get pod $POD_NAME | grep "Running" ; do sleep 1; done;

kubectl logs $POD_NAME | grep "Access your cluster at"
