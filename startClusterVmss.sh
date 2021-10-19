#!/bin/bash

# Usage: ./startClusterVMSS.sh -n <clusterName> -g <resourceGroup> [-r (to restart cluster)]
# Requires: Azure CLI, jq
# Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
# jq: https://stedolan.github.io/jq/

clusterName=""
resourceGroup=""
restart=0

while [ $# -gt 0 ]; do
  case "$1" in
    -n|-name|--name)
      clusterName="$2"
      ;;
    -g|-resource-group|--resource-group)
      resourceGroup="$2"
      ;;
    -restart|--restart)
      restart=1
      ;;
    *)
      printf "***************************\n"
      printf "* Error: Invalid argument.*\n"
      printf "***************************\n"
      exit 1
  esac
  shift
  shift
done

# check whether Azure CLI & jq installed

which az 2>&1 > /dev/null

if [ $? -gt 0 ]; then
  echo "Azure CLI not found. Please ensure you have it installed and in \$PATH"
  exit 1
fi

which jq 2>&1 > /dev/null

if [ $? -gt 0 ]; then
  echo "jq not found. Please ensure you have it installed and in \$PATH"
  exit 1
fi

# check user is logged-in to Azure CLI

signedInUser=$(az ad signed-in-user show)

if [[ -z "$signedInUser" ]]; then
  echo "Please login to Azure CLI before running this script"
  exit 1
fi

#clusterName="$1"
#resourceGroup="$2"

clusterObjectJson=$(az aks show -n $clusterName -g $resourceGroup -o json)

# check if cluster exists

if [[ ! -z "$clusterObjectJson" ]]; then
  clusterId=$(echo "$clusterObjectJson" | jq -r ".id")
  echo "Found cluster $clusterId"
else
  echo "Cluster not found. Nothing to do"
  exit 1
fi

nodePoolNames=$(echo  $clusterObjectJson | jq ".agentPoolProfiles[].name" -r)
nodeResourceGroup=$(echo  $clusterObjectJson | jq ".nodeResourceGroup" -r)
powerState=$(echo  $clusterObjectJson | jq ".powerState.code" -r)
vmssPrefix="aks-"
allVmssInRg=$(az vmss list -o tsv -g $nodeResourceGroup --query "[].name")

# check if cluster already started. Attempt to start if it's in a stopped state.

if [ "$powerState" == "Stopped" ]; then
  echo "Cluster is stopped. Starting cluster..."
  az aks start -n $clusterName -g $resourceGroup
else
  if [ "$restart" == 1 ]; then
    # restart the cluster if the restart flag was specified.
    echo "Restarting the cluster..."
    az aks stop -n $clusterName -g $resourceGroup && az aks start -n $clusterName -g $resourceGroup
  else
    echo "Cluster already started."
  fi
fi

echo -e "Found the following VMSS for this cluster: \n\n$allVmssInRg"

echo "$allVmssInRg" | while IFS=$'\n' read -r line
do
  echo starting VMSS $line in $nodeResourceGroup
  az vmss start --name $line --resource-group $nodeResourceGroup
done

az aks get-credentials -n $clusterName -g $resourceGroup --admin --overwrite
