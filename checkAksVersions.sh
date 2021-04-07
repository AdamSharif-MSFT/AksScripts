export REGIONS=$(az account list-locations --query "[].name" -o tsv)
##echo $1

echo $REGIONS | while IFS=$'\n' read -r line                                                                
do
  echo "--- $line ---\n"
  OUTPUT=$(az aks get-versions -l $line --query "orchestrators[?contains(orchestratorVersion,'1.20')].{Version:orchestratorVersion,Preview:isPreview}" -o table 2>/dev/null)
  echo $OUTPUT
  echo "\n"
done
