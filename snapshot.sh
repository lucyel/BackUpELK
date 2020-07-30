#!/bin/bash

#Variable
#IP 0
#Port 1
#archive dir 2
#username 3
#password 4

inputfile="infofile.txt"
declare -i i=0

while  read line ; do
	info[$i]=$line
	i=$((i+1))
done <"$inputfile"

#Get the 6 months ago in for format yyyy.mm
TIMESTAMP=$(date -d "6 months ago" +"%Y.%m")

#Get all of indices to the indicesList.txt file
curl -k -u ${info[3]}:${info[4]} "https://${info[0]}:${info[1]}/_cat/indices?h=i,sth" > indicesList.txt


#Filter the file according to the time format
indicesname=$(grep "$TIMESTAMP" indicesList.txt)
echo "Archiving the following indices."
echo $indicesname


#unfrozen the indices
unfrozen () {
	declare -i j=0

	while read line; do
		test[j]=$line

		while read doc; do
			testvar=($doc)
			data=${testvar[0]}
			status=${testvar[1]}

			if [[ $status = "true" ]]; then
				curl -k -X POST -u ${info[3]}:${info[4]} "https://${info[0]}:${info[1]}/$data/_unfreeze?pretty"
			fi
		done <<<"${test[j]}"

		j=$((j+1))
	done <<<"$indicesname"
}

#Set the indices replica number to 0 to minimize the size of index.
replicaTo0 () {
	curl -k -X PUT -u ${info[3]}:${info[4]} "https://${info[0]}:${info[1]}/$OUTPUT/_settings?pretty" -H 'Content-Type: application/json' -d'
	{
		"index" : {
			"number_of_replicas" : 0
		}
	}
	'
}

#Create the snapshot with the same name as the indiex.
createSnapshot () {
	curl -k -X PUT -u ${info[3]}:${info[4]} "https://${info[0]}:${info[1]}/_snapshot/${info[2]}/$OUTPUT?wait_for_completion=true" -H 'Content-Type: application/json' -d '
	{
		"indices": "'"$OUTPUT"'",
		"ignore_unavailable": false,
		"include_global_state": true
	}
	'
}

#Delete the snaphot
deletesnap () {
	curl -X DELETE -k -u ${info[3]}:${info[4]} "https://${info[0]}:${info[1]}/_snapshot/${info[2]}/$OUTPUT?pretty"
}

#Get status
snapshotstatus () {
	curl -k -u ${info[3]}:${info[4]} "https://${info[0]}:${info[1]}/_snapshot/${info[2]}/$OUTPUT"
}

#Delete indices
deleteindices () {
	curl -X DELETE "http://${info[0]}:${info[1]}/$OUTPUT?pretty"
}

while read -r OUTPUT
do
	echo $OUTPUT
	if [[ -f /backup/$OUTPUT.tar.bz2 ]]; then
		#if the backup alread exsist then continue the loop.
		echo "BackUp file already exsists."
		continue
	else
		date
		unfrozen
		replicaTo0
		createSnapshot

		#Get the status of the backup.
		BackUpStatus=$(snapshotstatus)

		#Compress the index and then delete the snapshot.
		if [[ $BackUpStatus = *'"state":"SUCCESS"'* ]]; then
		        tar -cjf /backup/$OUTPUT.tar.bz2 /snapshot
				deletesnap
	#			DeleteState=true
		fi

		#Delete the index.
		#if [ $DeleteState = "true" ]; then
		#	echo "Deleting indices $OUTPUT"
		#	deleteindices
		#	DeleteState=false
		#fi

	fi


done <<<"$indicesname"
