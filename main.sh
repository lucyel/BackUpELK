#!/bin/bash

x=$(df -h | grep "/$" | awk '{print $4}')
availsto=$(echo "${x%?}")

TIMESTAMP=$(date -d "6 months ago" +"%Y.%m")

curl -k -u elastic:... "https://10.1.6.203:9200/_cat/indices/*$TIMESTAMP*" > list_index.txt

cat list_index.txt | awk '{print $3, $10}' > list_index_filter.txt

sumofindex=$(cat list_index_filter.txt | awk '{ sum += $2; }
     END { print sum; }' "$@")


while true
do
    if[$((availsto)) >= $((sumofindex))]; then
        #./scritp.sh
        echo "test"
        break
    else
        sed -i '$ d' list_index_filter.txt
done
