RED='\033[0;31m'          # Red
GREEN='\033[0;32m'        # Green
NC='\033[0m'              # No Color

clusterName=msicluster
resourceGroup=aks-msicluster
subscriptionId=

kubeletIdentity=$(az aks show -n $clusterName -g $resourceGroup --query identityProfile.kubeletidentity.clientId -o tsv)
nodePools=$(az aks nodepool list -o tsv --cluster-name $clusterName -g $resourceGroup)
nodeResourceGroup=$(az aks show -o tsv -n $clusterName -g $resourceGroup --query nodeResourceGroup)
scalesets=$(az vmss list -o tsv --query "[].name" -g $nodeResourceGroup)
# az vmss show -n aks-nodepool1-14135066-vmss -g aks-msicluster-res --query "identity.userAssignedIdentities.*.clientId" -o tsv

# Iterate through VMSSes in the Infrastructure Resource Group of AKS cluster

echo "** Checking AKS cluster $clusterName in Resource Group $resourceGroup for kubelet MSI assignment issues **"

while read -r scaleset
do
    identities=$(az vmss show -n $scaleset -g aks-msicluster-res --query "identity.userAssignedIdentities.*.clientId" -o tsv)

    # Set found boolean to false

    identityFound=0

    # Iterate through the assigned identities on the current scaleset in the parent loop

    while read -r identity 
    do
        echo "------------------------------------------------------"
        echo "identity: $identity"
        echo "kubelet identity: $kubeletIdentity"
        echo "vmss name: $scaleset"
        echo "------------------------------------------------------\n"

        if [[ "$identity" == "$kubeletIdentity" ]]
        then 
            identityFound=1
        fi

    done <<<$identities

    if [ $identityFound -eq 1 ]
    then
        echo -e "${GREEN}Found kubelet identity $kubeletIdentity on agent pool VMSS $scaleset\n${NC}"
    else
        echo -e "${RED}Warning! Did not find kubelet identity $kubeletIdentity on agent pool VMSS $scaleset\n${NC}"
    fi
    
done <<<$scalesets
