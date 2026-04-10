#!/bin/bash

# Create a string variable with space-separated IP addresses
ip_string="10.2.3.4 10.4.5.7"

# Convert string to array
ip_array=($ip_string)

# Print the array
echo "Array contents:"
for ip in "${ip_array[@]}"; do
    echo "$ip"
done

# Print all elements at once
echo "All IPs: ${ip_array[@]}"

echo "IP[0]: ${ip_array[0]}"

# Print array length
echo "Array length: ${#ip_array[@]}"