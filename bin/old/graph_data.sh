#!/bin/bash

#field1: cpu
#field4: bwin
#field5: bwout
#field6: numplayers

if [[ ! $1 ]]; then
	echo "Crysis server - Plot outgoing bandwidth against playercount"
	echo "need path to server_profile.txt!"
	exit 1
fi

for i in {0..32}; do

	data=$(cat "$1" | awk "\$6 ~ /\y$i\y/" | awk '{print $5}') #dump all bwout fields with i numplayers

	sum="0"
	count="0"
	for value in $data; do
		count=$[$count + 1]
		sum="$sum+$value"
	done

	if [[ $count != "0" ]]; then
		echo -n "$i " >> graphdata.dat
		echo "scale=1; ($sum)/$count" | bc >> graphdata.dat
	fi

done

gnuplot -p -e "plot \"graphdata.dat\" using 1:2 with lines"
sleep 5
rm graphdata.dat
