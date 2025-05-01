# Proxmox VM/CT Deletion Script

A bash script for safely managing the deletion of Virtual Machines (VMs) and Containers (CTs) in Proxmox VE.

## Features

- Lists all VMs and CTs in your Proxmox environment
- Provides a confirmation prompt before starting the deletion process
- Allows batch deletion without prompting for each VM/CT
- Individual confirmation for each VM/CT when not using batch mode
- Gracefully stops VMs/CTs before deletion
- Comprehensive error handling and reporting
- Debug mode for troubleshooting
- Color-coded output for better readability

## Requirements

- Proxmox VE 6.x or newer
- Root access on the Proxmox host
- Bash shell

## Installation

1. Download the script:
   ```bash
   wget -O proxmox_delete.sh https://raw.githubusercontent.com/N0TScrooge/proxmox-delete-script/main/proxmox_delete.sh
   ```

2. Make it executable:
   ```bash
   chmod +x proxmox_delete.sh
   ```

## Usage

### Basic Usage

Run the script as root:

```bash
sudo ./proxmox_delete.sh
```

### Debug Mode

For detailed output and troubleshooting:

```bash
sudo ./proxmox_delete.sh -d
```

or

```bash
sudo ./proxmox_delete.sh --debug
```

### Help

To see usage information:

```bash
./proxmox_delete.sh -h
```

or

```bash
./proxmox_delete.sh --help
```

## How It Works

1. The script first checks if it's running as root and if required commands are available
2. Lists all VMs and CTs with their IDs and names
3. Asks for confirmation to proceed with deletion
4. Offers the option to delete all without further prompting
5. If batch deletion is not selected, asks for confirmation for each VM/CT
6. Stops each VM/CT before deletion
7. Deletes the VM/CT using the `--purge` option for complete removal
8. Provides statistics on successful and failed deletions

## Safety Features

- Multiple confirmation prompts
- Command checking before execution
- Error detection and handling
- Proper exit codes on errors
- Individual error reporting for each operation

## Warning

**This script permanently deletes VMs and CTs!** Make sure you have appropriate backups before using it in production environments.

## Contributing

Feel free to submit issues or pull requests to improve the script.

## License

This script is released under the CC BY-NC 4.0 with AI usage restrictions.
