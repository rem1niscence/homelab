#!/bin/bash

# This script applies Kubernetes YAML configuration files in a specified directory 
# and its subdirectories. If a YAML file has 'secret' in its name, the script uses 
# 'envsubst' to substitute environment variable references in the file before applying 
# it. The script first applies all secret files in a directory before applying the 
# non-secret files. The directory path is provided as a command-line argument when 
# running the script. 

# Usage:
# ./k8s_yaml_apply.sh /path/to/yaml/files

# Example:
# ./k8s_yaml_apply.sh /home/user/k8s/configs

# Before running this script, ensure that all environment variables referenced in your 
# secret files are on a .env file within the same directory where they will be applied.   
# Always ensure your YAML files are correctly set up before running this script.

set -e
function handleError {
  echo "error: ${1}"
  exit 1
}

trap 'handleError $?' ERR

# Check if an argument is given
if [ $# -eq 0 ]; then
    echo "No directory provided. Usage: $0 /path/to/yaml"
    exit 1
fi

# Use the first argument as the directory path
DIR=$1

# Export your environment variables here if needed
# export MY_VAR=my_value

# First, apply secret files in each directory
find "$DIR" -type f -name "*secret*.yml" | while read secret_file; do
    set -o allexport
    source .env
    # Perform envsubst and output to a new file
    envsubst < "$secret_file" > "sec-applied.yml"
    set +o allexport
    # Apply the new file with kubectl
    kubectl apply -f "sec-applied.yml"
done

# Next, apply the other files in each directory
find "$DIR" -type f -name "*.yml" ! -name "*secret*.yml" | while read file; do
    # Apply the file with kubectl
    kubectl apply -f "$file"
done
