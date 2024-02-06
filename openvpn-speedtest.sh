#!/bin/bash

################################################################################
# Script: openvpn-speedtest.sh
# Author: OpenAI GPT-3, with modifications
# Description: This script performs internet speed tests using speedtest-cli
# through different OpenVPN servers. It requires speedtest-cli, OpenVPN, bc,
# and GNU Screen to be installed.
# 
# Before running the script, ensure that:
# 1. speedtest-cli is installed (e.g., 'sudo apt install speedtest-cli').
# 2. OpenVPN is installed (e.g., 'sudo apt install openvpn').
# 3. bc is installed (e.g., 'sudo apt install bc').
# 4. GNU Screen is installed (e.g., 'sudo apt install screen').
# 5. The user needs to edit the script to include each OpenVPN server's 
#    configuration file. Edit the SERVERS array in the script to specify the
#    server name and its corresponding OpenVPN configuration file.
# 
# Instructions:
# - Modify the SERVERS array in this script to include the name of each server
#   along with its OpenVPN configuration file.
# - Run the script using 'bash speedtest.sh'.
################################################################################

# Define a list of OpenVPN servers along with their configuration files
declare -A SERVERS=(
    ["server1"]="/home/openvpn/conf/server1.ovpn"
    ["server2"]="/home/openvpn/conf/server2.ovpn"
    ["server3"]="/home/openvpn/conf/server3.ovpn"
)

# Terminate any existing "OpenVPN" screen session
sudo screen -S OpenVPN -X quit &> /dev/null

# Function to perform speed test using speedtest-cli
perform_speed_test() {
    server=$1
    config_file=$2
    echo "Connecting to $server..."
    # Start OpenVPN connection
    sudo openvpn --config "$config_file" --daemon

    # Wait until OpenVPN is fully running
    while ! pgrep -x "openvpn" > /dev/null; do sleep 1; done

    # Wait a bit longer to ensure connection is established
    sleep 10

    # Run speedtest-cli and capture the results
    echo "Running speed test for $server..."
    speed=$(speedtest-cli --simple 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "Speed test result for $server:"
        echo "$speed"
        RESULTS["$server"]=$speed  # Store the speed test result
    else
        echo "Failed to run speed test for $server: $speed"
    fi

    # Disconnect OpenVPN
    sudo pkill -f "openvpn --config"
}

# Array to store speed test results
declare -A RESULTS

# Perform speed test for each server
for server in "${!SERVERS[@]}"; do
    config_file=${SERVERS[$server]}
    echo "-----------------------------------------------------"
    echo "Testing server: $server"
    perform_speed_test "$server" "$config_file"
    echo "-----------------------------------------------------"
done

# Sort the results by download speed
#echo "Sorting results by download speed..."
#for server in "${!RESULTS[@]}"; do
#    echo "${RESULTS[$server]}" | grep -E "Download|Upload"
#done | sort -k2 -n -r

# Find the server with the fastest download speed
fastest_server=""
fastest_speed=0

for server in "${!RESULTS[@]}"; do
    download_speed=$(echo "${RESULTS[$server]}" | grep -oP 'Download: \K[^ ]+')
    if (( $(echo "$download_speed > $fastest_speed" | bc -l) )); then
        fastest_server=$server
        fastest_speed=$download_speed
    fi
done

# Display the server with the fastest download speed
echo "Server with the fastest download speed: $fastest_server (Download Speed: $fastest_speed Mbit/s)"

# Create a new screen session named "OpenVPN" and connect to the fastest OpenVPN server
sudo screen -S OpenVPN -d -m sudo openvpn --config "${SERVERS[$fastest_server]}"
