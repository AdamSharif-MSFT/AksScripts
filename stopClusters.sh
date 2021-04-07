input=$(az aks list --query "[].[name, resourceGroup]" -o tsv)
echo $input | while IFS=$'\n' read -r line
do
  clusterName=$(echo $line | awk '{print $1}')
  resourceGroup=$(echo $line | awk '{print $2}')
  echo stopping $clusterName in $resourceGroup
  az aks stop --name $clusterName --resource-group $resourceGroup --no-wait
done
