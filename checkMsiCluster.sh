# Bash script to check that the kubelet identity of the AKS cluster is assigned to all node pools (prevent image pull failures from ACR, etc.)
# 
# Usage: 
# export clusterName=<clusterName>
# export resourceGroup=<resourceGroup>
# bash ./checkMsiCluster.sh

RED='\033[0;31m'          # Red
GREEN='\033[0;32m'        # Green
YELLOW='\033[1;33m'
NC='\033[0m'              # No Color

# clusterName=<clusterName>
# resourceGroup=<clusterResourceGroupName>
# subscriptionId=<notUsed>

kubeletIdentity=$(az aks show -n $clusterName -g $resourceGroup --query identityProfile.kubeletidentity.clientId -o tsv)
nodePools=$(az aks nodepool list -o tsv --cluster-name $clusterName -g $resourceGroup)
nodeResourceGroup=$(az aks show -o tsv -n $clusterName -g $resourceGroup --query nodeResourceGroup)
scalesets=$(az vmss list -o tsv --query "[].name" -g $nodeResourceGroup)

# Iterate through VMSSes in the Infrastructure Resource Group of AKS cluster

printf "${YELLOW}\n** Checking AKS cluster $clusterName in Resource Group $resourceGroup for kubelet MSI assignment issues **\n\n${NC}"

while read -r scaleset
do
    identities=$(az vmss show -n $scaleset -g aks-msicluster-res --query "identity.userAssignedIdentities.*.clientId" -o tsv)

    # Set found boolean to false

    identityFound=0

    
    printf -- "---------------------------------------------------------------\n"
    printf "vmss name: $scaleset\n"
    printf "kubelet identity: $kubeletIdentity\n"

    # Iterate through the assigned identities on the current scaleset in the parent loop

    while read -r identity 
    do
        printf "identity: $identity\n"

        if [[ "$identity" == "$kubeletIdentity" ]]
        then 
            identityFound=1
        fi

    done <<<$identities

    printf -- "---------------------------------------------------------------\n\n"

    if [ $identityFound -eq 1 ]
    then
        printf "${GREEN}Found kubelet identity $kubeletIdentity on agent pool VMSS $scaleset\n\n${NC}"
    else
        printf "${RED}Warning! Did not find kubelet identity $kubeletIdentity on agent pool VMSS $scaleset\n\n${NC}"
    fi
    
done <<<$scalesets
