#!/bin/bash

##############################################
####         System monitoring tool       ####
####               of the VPS             ####
####   Developed for the Agoric Testnet   ####
##############################################


### Script start ###

# Telegram bot API token. Use @botfather to create a new bot
TELEGRAM_TOKEN=""

# Alerts will be sent here. It can be a public, private or user chat
TELEGRAM_CHAT=""

SERVER_NAME=""

# bc package has to be installed "apt install bc"
CORES_NUMBER=$(grep -c ^processor /proc/cpuinfo)

##################
## Disk Monitor ##
##################
# Alerting if the server is 90% full or above
## IMPORTANT ## Check which /dev/ folder is the one you want to monitor first. It changes depending of the platform of yourt VPS
##    -Contabo --> sda2
##    -Vultr   --> vda1
##    -Others  --> sda1
disk_used=$(df -H | grep -m 1 '/dev/sda2' | awk '{print $5}' | cut -d'%' -f1)
if (( $(echo $disk_used '>' 90 | bc -l) )); then
   error_messages_array+=("*STORAGE WARNING* | Running out of space >> $disk_used% disk used")
fi

######################
## CPU load monitor ##
######################
# Alerting if:
#  - The CPU load is 90% or above
#  - The CPU load is 70% or above 
# Time interval of the average CPU load:
#  - $12 --> 1min
#  - $13 --> 5min
#  - $14 --> 15min (default option)
cpu_load=$(top -b -n1 | grep "load average" | awk '{print $14}' | cut -d',' -f1)
cpu_load_percentage=$(echo "scale=2; $cpu_load/$CORES_NUMBER*100" | bc -l)

if (( $(echo $cpu_load_percentage '>' 90 | bc -l) )); then
   error_messages_array+=("*CPU CRITICAL* | CPU load is very high >> $cpu_load_percentage% is being used")
elif (( $(echo $cpu_load_percentage '>' 70 | bc -l) )); then
   error_messages_array+=("*CPU WARNING* | CPU load is high >> $cpu_load_percentage% is being used")
fi

#############################
## Memory RAM used monitor ##
#############################
# Alerting if:
#  - The RAM load is 90% or above
#  - The RAM load is 70% or above
## IMPORTANT ##
# The grep in the first command depends of the unit of measure. You should apply "top -b -n1" and see which one your VPS is using
#    -Contabo: grep "KiB Mem"
#    -Vultr:   grep "MiB Mem"
memory_used_percentage=$(top -b -n1 | grep "KiB Mem" | awk '{print $8/$4*100}')
if (( $(echo $memory_used_percentage '>' 90 | bc -l) )); then
   error_messages_array+=("*RAM CRITICAL* | Memory used is very high >> $memory_used_percentage% is being used")
elif (( $(echo $memory_used_percentage '>' 70 | bc -l) )); then
   error_messages_array+=("*RAM WARNING* | Memory used is high >> $memory_used_percentage% is being used")
fi

###########################
## Network speed monitor ##
###########################

# Alerting if the ping timme is higher than 80ms
# We are using 1.1.1.1 as an example, but it could be whatever you desire
ping_time=$(ping -c 4 1.1.1.1  | tail -1 | awk -F '/' '{print $5}')

if (( $(echo $ping_time '>' 80 | bc -l) )); then
   error_messages_array+=("*NETWORK CRITICAL* | Network is slow >> The ping time to 1.1.1.1 was $ping_time")
fi


####################
## Sending errors ##
####################
for error_message in "${error_messages_array[@]}"
do
  echo "$error_message"
  curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT}&parse_mode=Markdown&text=*$SERVER_NAME* |  $error_message"
done
exit 3
