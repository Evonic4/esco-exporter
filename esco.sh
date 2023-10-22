#!/bin/bash
export PATH="$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"
ver="v0.1"
fhome=/usr/share/esco/
cd $fhome


function init() 
{
logger "init start"

first_str=22
ELKendpoint=$(sed -n $first_str"p" $fhome"sett.conf" | tr -d '\r')
ELKport=$(sed -n $((first_str+1))"p" $fhome"sett.conf" | tr -d '\r')
ELKuser=$(sed -n $((first_str+2))"p" $fhome"sett.conf" | tr -d '\r')
ELKpass=$(sed -n $((first_str+3))"p" $fhome"sett.conf" | tr -d '\r')
ELKup=$ELKuser":"$ELKpass
namejob=$(sed -n $((first_str+4))"p" $fhome"sett.conf" | tr -d '\r')
sec4=$(sed -n $((first_str+5))"p" $fhome"sett.conf" | tr -d '\r')
proxy=$(sed -n $((first_str+6))"p" $fhome"sett.conf" | tr -d '\r')
max_time_elk=$(sed -n $((first_str+7))"p" $fhome"sett.conf" | tr -d '\r')
max_time_pushgateway=$(sed -n $((first_str+8))"p" $fhome"sett.conf" | tr -d '\r')
pushg_ip=$(sed -n $((first_str+9))"p" $fhome"sett.conf" | tr -d '\r')
pushg_port=$(sed -n $((first_str+10))"p" $fhome"sett.conf" | tr -d '\r')
optional1=$(sed -n $((first_str+11))"p" $fhome"sett.conf" | tr -d '\r')
first5_str=$((first_str+13))

logger "init sec4="$sec4
logger "init max_time_elk="$max_time_elk
logger "init first5_str="$first5_str

str_col3=$(grep -cv "^---" $fhome"sett.conf")
if [ "$str_col3" -gt "$((first5_str+3))" ]; then
	all5=$(((str_col3-first5_str)/5))
	#str_col3=$(grep -cv "^---" "./sett.conf"); echo $str_col3; echo $(((str_col3-11)/5))
else
	all5=0
fi
logger "init all5="$all5	#пятерок всего
if [ "$all5" -eq "0" ]; then
	logger "init ERROR: all5=0, exit"
	exit 0
fi
}


function logger()
{
local date1=$(date '+ %Y-%m-%d %H:%M:%S')
echo $date1" esco: "$1
}


constructor ()
{
logger "constructor "$i" start"
rm -f $fhome$i".txt"

echo "#!/bin/bash" > $fhome$i".sh"
echo "export PATH=\"\$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin\"" >> $fhome$i".sh"

#echo "PID=\$\$" >> $fhome$i".sh"
#echo "echo \$PID > "$fhome$i".pid" >> $fhome$i".sh"

#-------------------------------------
if [ -z "$proxy" ]; then
echo "curl -k -m "$max_time_elk" -u "$ELKup" -s --location '"$ELKendpoint":"$ELKport"/"$index_name"/_count' \\" >> $fhome$i".sh"
else
echo "curl -k --proxy "$proxy" -m "$max_time_elk" -u "$ELKup" -s --location '"$ELKendpoint":"$ELKport"/"$index_name"/_count' \\" >> $fhome$i".sh"
fi

echo "--header 'Content-Type: application/json' \\" >> $fhome$i".sh"
echo "--data '{ " >> $fhome$i".sh"
echo "  \"query\": {" >> $fhome$i".sh"
echo "    \"match\": {" >> $fhome$i".sh"
echo "      \""$field_find"\": \""$query"\"" >> $fhome$i".sh"
echo "    }" >> $fhome$i".sh"
echo "  }" >> $fhome$i".sh"
echo "}'"$post_processing >> $fhome$i".sh"
#echo "}'"$post_processing" > "$fhome$i".txt" >> $fhome$i".sh"
#------------------------------------
#echo "rm -f "$fhome$i".pid" >> $fhome$i".sh"

$fhome"setup.sh"
}

zapushgateway ()
{
logger "zapushgateway"
echo $name_metric" "$count | curl -m $max_time_pushgateway --data-binary @- "http://"$pushg_ip":"$pushg_port"/metrics/job/"$namejob
}



next_five ()
{
local mn=0
mn=$((i*6))

index_name=$(sed -n $((first5_str+mn))"p" $fhome"sett.conf" | tr -d '\r')
field_find=$(sed -n $((first5_str+1+mn))"p" $fhome"sett.conf" | tr -d '\r')
query=$(sed -n $((first5_str+2+mn))"p" $fhome"sett.conf" | tr -d '\r')
post_processing=$(sed -n $((first5_str+3+mn))"p" $fhome"sett.conf" | tr -d '\r')
name_metric=$(sed -n $((first5_str+4+mn))"p" $fhome"sett.conf" | tr -d '\r')

logger "next_five index_name="$index_name
logger "next_five field_find="$field_find
logger "next_five query="$query
logger "next_five post_processing="$post_processing
logger "next_five name_metric="$name_metric
}

next_five2 ()
{
local mn=0
mn=$((i2*6))
name_metric=$(sed -n $((first5_str+4+mn))"p" $fhome"sett.conf" | tr -d '\r')
logger "next_five2 name_metric="$name_metric
}


great_five ()
{
logger "great_five start"
for (( i=0;i<$all5;i++)); do
	logger "great_five -----i="$i"-----"
	next_five;
	constructor;
done
}

watcher ()
{
local wn=0
logger "watcher"
count=0

for (( i2=0;i2<$all5;i2++)); do
	logger "watcher -----i2="$i2"----->"
	
	next_five2;
	count=$(eval $fhome$i2".sh")
	if [[ $count =~ ^[0-9]+$ ]]; then
		logger "watcher OK count="$count
		zapushgateway;
		echo 0 > $fhome$i2".txt"
	else
		logger "watcher ERROR count="$count" wn="$wn 
		if [ "$optional1" -gt "0" ]; then
			[ -f $fhome$i2".txt" ] && wn=$(sed -n 1"p" $fhome$i2".txt" | tr -d '\r')
			wn=$((wn+1))
			[ "$wn" -ge "$optional1" ] && count=-1 && zapushgateway && wn=0
			echo $wn > $fhome$i2".txt"
		fi
	fi
done

}



#START
logger " "
logger "start esco "$ver
su pushgateway -c '/usr/local/bin/pushgateway --web.listen-address=0.0.0.0:9098' -s /bin/bash 1>/dev/null 2>/dev/null &
sleep 5
init;
great_five;

while true
do
watcher;
sleep $sec4
done
