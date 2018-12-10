#!/bin/bash
#
# This script counts downloaded or uploaded data at specific time.

# Default interface all
INTERFACE='eth0'

# Listen specific port. 
PORT='80'

# How many second for listen.
DURATION='10' 

usage() {
    # Display the usage and exit
    echo "Usage ${0} [-duD] [-i INTERFACE] [-p PORT] [-t SECONDS] [-o OUTPUT FILE] [IP_ADDRESS]" >&2
    echo "  -i INTERFACE  Listen specific interface. Default: ${INTERFACE}" >&2 
    echo "  -p PORT       Listen specific port. Default: ${PORT}" >&2
    echo "  -t SECONDS    Listen duration. Default: ${DURATION} seconds." >&2 
    echo '  -o FILE       Output mode. Records file output data.' >&2
    echo '  -d            Download mode. Calculate the download data.' >&2
    echo '  -u            Upload mode. Calculate the upload data.' >&2
    echo '  -D            Detail mode. Detail output data.' >&2
    echo '  -h            Information about this script.' >&2
    exit ${EXIT_STATUS}
}

# Make sure run as root or superuser priveleges.
if [[ "${UID}" -ne 0 ]]
then
   echo 'Please run with sudo or as root.' >&2
   EXIT_STATUS='1'
   usage
fi

EXIT_STATUS='0'

while getopts i:p:t:f:o:duDh OPTION
do
    case ${OPTION} in
     i) INTERFACE="${OPTARG}" ;;
     p) PORT="${OPTARG}" ;;
     t) DURATION="${OPTARG}" ;;
     o) OUTPUT_FILE="${OPTARG}" ;;
     d) DOWNLOAD_MODE='true' ;;
     u) UPLOAD_MODE='true' ;;
     D) DETAIL_MODE='true' ;;
     h) usage 2>&1 ;;
     ?) EXIT_STATUS='1'
        usage ;;
    esac
done

# Information output.
echo "Listening port ${PORT} for ${DURATION} seconds.." 

# Edit port for no filter.
PORT="port ${PORT}"

# Remove the options while leaving the remaining arguments.
shift "$(( OPTIND - 1 ))"

# Ip address is exist or not
if [[ "${#}" -gt 0 ]]
then
    IP_ADDRESS="host ${@} and"
    
    # Upload or download mode.
    if [[ "${DOWNLOAD_MODE}" = 'true' ]]
    then
        TARGET='src'
        PORT="dst  ${PORT}"
    elif [[ "${UPLOAD_MODE}" = 'true' ]]
    then
        TARGET='dst'
        PORT="src  ${PORT}"
    fi
else
    MY_IP_ADDRESS=$(ifconfig "${INTERFACE}" | head -2 | tail -1 | awk '{print $2}')
    MY_IP_ADDRESS="host ${MY_IP_ADDRESS} and"

    if [[ "${DOWNLOAD_MODE}" = 'true' ]]
    then
        TARGET="dst ${MY_IP_ADDRESS}"
        PORT="dst  ${PORT}"
    elif [[ "${UPLOAD_MODE}" = 'true' ]]
    then
        TARGET="src ${MY_IP_ADDRESS}"
        PORT="src  ${PORT}"
    fi
fi

# Output file doesn't exist.
if [ -z ${OUTPUT_FILE+x} ] 
then 
    DATE_TIME=$(date '+%d-%m-%Y')
    OUTPUT_FILE="networkcheck-${DATE_TIME}"
    DELETE_FILE='true'
fi

TCPDUMP_COMMAND="sudo timeout ${DURATION} tcpdump -i ${INTERFACE} -n ${TARGET} ${IP_ADDRESS} ${PORT}"
${TCPDUMP_COMMAND}  > "${OUTPUT_FILE}" 2> /dev/null

# Make sure tcpdump work correctly.
# Timeout default exit status 124.
if [[ "${?}" -ne 124 ]]
then
    echo "${0} is crashed. Make sure input values are correct."
    echo ''
    rm -rf "${OUTPUT_FILE}"
    EXIT_STATUS='1'
    usage
else 
    echo 'Done.'
    echo ''
fi

# Calculating result.
TOTAL_PACKET=$(cat "${OUTPUT_FILE}" | grep -v 'length 0' | wc -l | awk '{print $1}')
SUM_BYTE=$(cat "${OUTPUT_FILE}" | awk '{SUM+=$NF} END {print SUM}')

echo  "Ip Address:     ${@}"
echo  "Duration:       ${DURATION} seconds"
echo  "Total Packet:   ${TOTAL_PACKET}"
echo  -n "Megabyte:       ";
echo "${SUM_BYTE}" | awk '{print $1 / (1024 ** 2)}'
echo  -n "Mb/sec:         ";
echo "${SUM_BYTE} ${DURATION}" | awk '{print ($1 / (1024 ** 2)) / $2}'

# If detail mode true then print result of detail.
if [[ "${DETAIL_MODE}" = 'true' ]]
then
echo ''
echo ' SECOND   MEGABYTE'
cat "${OUTPUT_FILE}" | grep . | awk -F '.' '{print $1}' | uniq | while read LINE; do echo -n "${LINE}   " ; cat "${OUTPUT_FILE}" | grep "${LINE}" | grep -v 'length 0' | awk '{SUM+=$NF} END {print  SUM}' |  awk '{printf "%.3f\n",  $1 / (1024 ** 2)}'; done
fi

# If user doesn't need output then remove output file.
if [[ "${DELETE_FILE}" = 'true' ]]
then
    rm -rf "${OUTPUT_FILE}"
fi

exit ${EXIT_STATUS}