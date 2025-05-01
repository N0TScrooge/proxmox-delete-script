#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Debug mode (disabled by default)
DEBUG_MODE=0

# Process command line arguments
for arg in "$@"; do
    case $arg in
        -d|--debug)
            DEBUG_MODE=1
            shift
            ;;
    esac
done

# Debug information output
debug_log() {
    if [ $DEBUG_MODE -eq 1 ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
    return $?
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Check if required commands exist
if ! command_exists qm; then
    echo -e "${RED}Command 'qm' not found. Make sure PVE CLI is installed and available.${NC}"
    exit 1
fi

if ! command_exists pct; then
    echo -e "${RED}Command 'pct' not found. Make sure PVE CLI is installed and available.${NC}"
    exit 1
fi

# Функция для получения списка всех VM и CT
get_vm_ct_list() {
    # Получаем список VM и CT, сортируем по ID
    qm list | tail -n +2 | awk '{print $1, $2, "VM"}' > /tmp/vm_list.txt
    pct list | tail -n +2 | awk '{print $1, $2, "CT"}' > /tmp/ct_list.txt
    
    # Объединяем списки и сортируем по ID
    cat /tmp/vm_list.txt /tmp/ct_list.txt | sort -n > /tmp/all_list.txt
    
    # Возвращаем количество найденных VM и CT
    wc -l < /tmp/all_list.txt
}

# Print the list of VMs and CTs
print_vm_ct_list() {
    echo -e "${GREEN}Found the following virtual machines and containers:${NC}"
    echo -e "${YELLOW}ID\tNAME\t\tTYPE${NC}"
    echo "--------------------------------------"
    
    while read -r id name type; do
        # Check name length for formatting
        if [ ${#name} -lt 8 ]; then
            echo -e "$id\t$name\t\t\t$type"
        else
            echo -e "$id\t$name\t\t$type"
        fi
    done < /tmp/all_list.txt
    
    echo "--------------------------------------"
}

# Delete VM or CT
delete_vm_ct() {
    local id=$1
    local name=$2
    local type=$3
    local output=""
    local error=""
    local status=0
    
    if [ "$type" == "VM" ]; then
        echo -e "${YELLOW}Stopping VM $id ($name)...${NC}"
        
        # Stop VM with output and error capture
        output=$(qm stop $id --timeout 120 2> >(error=$(cat); echo "$error" >&2))
        status=$?
        
        if [ $status -ne 0 ] || [[ "$error" == *[Ee]rror* ]]; then
            echo -e "${RED}Error stopping VM $id: $error${NC}"
            if [ $DEBUG_MODE -eq 1 ]; then
                echo -e "${BLUE}[DEBUG] Command status: $status${NC}"
                echo -e "${BLUE}[DEBUG] Output:${NC}"
                echo "$output"
            fi
            echo -e "${YELLOW}Continuing with deletion...${NC}"
        fi
        
        echo -e "${RED}Deleting VM $id ($name)...${NC}"
        
        # Delete VM with output and error capture
        output=$(qm destroy $id --purge 2> >(error=$(cat); echo "$error" >&2))
        status=$?
        
        if [ $status -ne 0 ] || [[ "$error" == *[Ee]rror* ]]; then
            echo -e "${RED}Error deleting VM $id: $error${NC}"
            if [ $DEBUG_MODE -eq 1 ]; then
                echo -e "${BLUE}[DEBUG] Command status: $status${NC}"
                echo -e "${BLUE}[DEBUG] Output:${NC}"
                echo "$output"
            fi
            return 1
        fi
    else
        echo -e "${YELLOW}Stopping CT $id ($name)...${NC}"
        
        # Stop CT with output and error capture (without timeout option)
        output=$(pct stop $id 2> >(error=$(cat); echo "$error" >&2))
        status=$?
        
        if [ $status -ne 0 ] || [[ "$error" == *[Ee]rror* ]]; then
            echo -e "${RED}Error stopping CT $id: $error${NC}"
            if [ $DEBUG_MODE -eq 1 ]; then
                echo -e "${BLUE}[DEBUG] Command status: $status${NC}"
                echo -e "${BLUE}[DEBUG] Output:${NC}"
                echo "$output"
            fi
            echo -e "${YELLOW}Continuing with deletion...${NC}"
        fi
        
        echo -e "${RED}Deleting CT $id ($name)...${NC}"
        
        # Delete CT with output and error capture
        output=$(pct destroy $id --purge 2> >(error=$(cat); echo "$error" >&2))
        status=$?
        
        if [ $status -ne 0 ] || [[ "$error" == *[Ee]rror* ]]; then
            echo -e "${RED}Error deleting CT $id: $error${NC}"
            if [ $DEBUG_MODE -eq 1 ]; then
                echo -e "${BLUE}[DEBUG] Command status: $status${NC}"
                echo -e "${BLUE}[DEBUG] Output:${NC}"
                echo "$output"
            fi
            return 1
        fi
    fi
    
    echo -e "${GREEN}$type $id ($name) successfully deleted${NC}"
    return 0
}

# Main function
main() {
    # Get and display list of VMs and CTs
    local count=$(get_vm_ct_list)
    
    # Check if an error occurred
    if [ $? -ne 0 ]; then
        echo -e "${RED}An error occurred while getting the list of VMs and CTs${NC}"
        exit 1
    fi
    
    if [ "$count" -eq 0 ]; then
        echo -e "${RED}No VMs or CTs found${NC}"
        exit 0
    fi
    
    print_vm_ct_list
    
    # Request confirmation to start deletion process
    echo -en "${RED}Do you really want to delete all listed VMs and CTs? [y/N]: ${NC}"
    confirm=""
    read -r confirm < /dev/tty
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}Operation cancelled.${NC}"
        exit 0
    fi
    
    # Ask if user wants to delete all without prompting
    delete_all=""
    echo -en "${YELLOW}Delete all without asking? [y/N]: ${NC}"
    read -r delete_all < /dev/tty
    
    # Counters for successful and failed operations
    local success_count=0
    local fail_count=0
    
    # Process all VMs and CTs for deletion
    while read -r id name type; do
        if [[ "$delete_all" == "y" || "$delete_all" == "Y" ]]; then
            if delete_vm_ct "$id" "$name" "$type"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        else
            # Request confirmation once for each VM/CT and read input from terminal
            delete_confirm=""
            echo -en "${YELLOW}Delete $type $id ($name)? [y/N]: ${NC}"
            read -r delete_confirm < /dev/tty
            
            # Check response
            if [[ "$delete_confirm" == "y" || "$delete_confirm" == "Y" ]]; then
                if delete_vm_ct "$id" "$name" "$type"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
            else
                echo -e "${GREEN}Skipping $type $id ($name)${NC}"
            fi
        fi
    done < /tmp/all_list.txt
    
    # Clean up temporary files
    rm -f /tmp/vm_list.txt /tmp/ct_list.txt /tmp/all_list.txt
    
    # Display final statistics
    echo -e "${GREEN}Operation completed.${NC}"
    echo -e "${GREEN}Successfully deleted: $success_count${NC}"
    if [ $fail_count -gt 0 ]; then
        echo -e "${RED}Failed to delete: $fail_count${NC}"
    fi
}

# Help documentation
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Script for deleting virtual machines and containers in Proxmox VE"
    echo ""
    echo "Options:"
    echo "  -d, --debug     Enable debug mode"
    echo "  -h, --help      Show this help"
    echo ""
    echo "N0TScrooge"
}

# Process command line arguments
for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            exit 0
            ;;
    esac
done

# Run main function
main
