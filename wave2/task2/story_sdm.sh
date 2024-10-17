#!/bin/bash

# Colors for screen prompts
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color (reset)

# Display the ASCII Art Banner
display_banner() {
    cat << "EOF"
                                                                               
   d888888o. 8888888 8888888888 ,o888888o.     8 888888888o. `8.`8888.      ,8' 
 .`8888:' `88.     8 8888    . 8888     `88.   8 8888    `88. `8.`8888.    ,8'  
 8.`8888.   Y8     8 8888   ,8 8888       `8b  8 8888     `88  `8.`8888.  ,8'   
 `8.`8888.         8 8888   88 8888        `8b 8 8888     ,88   `8.`8888.,8'    
  `8.`8888.        8 8888   88 8888         88 8 8888.   ,88'    `8.`88888'     
   `8.`8888.       8 8888   88 8888         88 8 888888888P'      `8. 8888      
    `8.`8888.      8 8888   88 8888        ,8P 8 8888`8b           `8 8888      
8b   `8.`8888.     8 8888   88 8888       ,8P  8 8888 `8b.          8 8888      
`8b.  ;8.`8888     8 8888    ` 8888     ,88'   8 8888   `8b.        8 8888      
 `Y8888P ,88P'     8 8888       `8888888P'     8 8888     `88.      8 8888      

:'######::'##::: ##::::'###::::'########:::'######::'##::::'##::'#######::'########:   
'##... ##: ###:: ##:::'## ##::: ##.... ##:'##... ##: ##:::: ##:'##.... ##:... ##..::   
 ##:::..:: ####: ##::'##:. ##:: ##:::: ##: ##:::..:: ##:::: ##: ##:::: ##:::: ##::::   
. ######:: ## ## ##:'##:::. ##: ########::. ######:: #########: ##:::: ##:::: ##::::   
:..... ##: ##. ####: #########: ##.....::::..... ##: ##.... ##: ##:::: ##:::: ##::::   
'##::: ##: ##:. ###: ##.... ##: ##::::::::'##::: ##: ##:::: ##: ##:::: ##:::: ##::::   
. ######:: ##::. ##: ##:::: ##: ##::::::::. ######:: ##:::: ##:. #######::::: ##::::   
:......:::..::::..::..:::::..::..::::::::::......:::..:::::..:::.......::::::..:::::   
'########:::'#######::'##:::::'##:'##::: ##:'##::::::::'#######:::::'###::::'########::
 ##.... ##:'##.... ##: ##:'##: ##: ###:: ##: ##:::::::'##.... ##:::'## ##::: ##.... ##:
 ##:::: ##: ##:::: ##: ##: ##: ##: ####: ##: ##::::::: ##:::: ##::'##:. ##:: ##:::: ##:
 ##:::: ##: ##:::: ##: ##: ##: ##: ## ## ##: ##::::::: ##:::: ##:'##:::. ##: ##:::: ##:
 ##:::: ##: ##:::: ##: ##: ##: ##: ##. ####: ##::::::: ##:::: ##: #########: ##:::: ##:
 ##:::: ##: ##:::: ##: ##: ##: ##: ##:. ###: ##::::::: ##:::: ##: ##.... ##: ##:::: ##:
 ########::. #######::. ###. ###:: ##::. ##: ########:. #######:: ##:::: ##: ########::
........::::.......::::...::...:::..::::..::........:::.......:::..:::::..::........:::
'##::::'##::::'###::::'##::: ##::::'###:::::'######:::'########:'########::            
 ###::'###:::'## ##::: ###:: ##:::'## ##:::'##... ##:: ##.....:: ##.... ##:            
 ####'####::'##:. ##:: ####: ##::'##:. ##:: ##:::..::: ##::::::: ##:::: ##:            
 ## ### ##:'##:::. ##: ## ## ##:'##:::. ##: ##::'####: ######::: ########::            
 ##. #: ##: #########: ##. ####: #########: ##::: ##:: ##...:::: ##.. ##:::            
 ##:.:: ##: ##.... ##: ##:. ###: ##.... ##: ##::: ##:: ##::::::: ##::. ##::            
 ##:::: ##: ##:::: ##: ##::. ##: ##:::: ##:. ######::: ########: ##:::. ##:            
..:::::..::..:::::..::..::::..::..:::::..:::......::::........::..:::::..::  by https://moonli.me

EOF
}

display_banner
# Install aria2 if not present
if ! [ -x "$(command -v aria2c)" ]; then
    echo "Installing aria2 for faster downloads..."
    sudo apt-get install -y aria2
fi

# Get user input for snapshot URLs
read -p "Enter the URL for the Story Consensus Node snapshot: " STORY_SNAPSHOT_URL
read -p "Enter the URL for the Story Geth Node snapshot: " GETH_SNAPSHOT_URL

# Define file paths and directories
STORY_SNAPSHOT_FILE="tmp/story_snapshot.lz4"
GETH_SNAPSHOT_FILE="tmp/geth_snapshot.lz4"
STORY_SERVICE="story.service"
GETH_SERVICE="story-geth.service"
STORY_PRIV_VALIDATOR_STATE="$HOME/.story/story/data/priv_validator_state.json"
STORY_BACKUP="$HOME/.story/priv_validator_state.json.backup"
GETH_CHAINDATA_DIR="$HOME/.story/geth/iliad/geth/chaindata"
STORY_DATA_DIR="$HOME/.story/story/data"
GETH_CHAINDATA_EXTR_DIR="$HOME/.story/geth/iliad/geth"
STORY_DATA_EXTR_DIR="$HOME/.story/story"

# Remove existing archives and aria2 files
remove_existing_aria2_files() {
    rm -f /tmp/story_snapshot.lz4.aria2
    rm -f /tmp/geth_snapshot.lz4.aria2
      rm -f /tmp/story_snapshot.lz4
    rm -f /tmp/geth_snapshot.lz4
}

# Display file size in a human-readable format
get_file_size() {
    local url=$1
    curl -sI $url | grep -i Content-Length | awk '{print $2}' | tr -d '\r' | numfmt --to=iec-i --suffix=B
}

# Download a snapshot with progress and time remaining
download_snapshot_with_curl() {
    local url=$1
    local output_file=$2

    echo "Retrying download with curl..."
    curl -L -o $output_file $url

    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed for $url using curl.${NC}"
        exit 1
    else
        echo -e "${BLUE}Download successful using curl.${NC}"
    fi
}

# Download snapshot
download_snapshot() {
    local url=$1
    local output_file=$2

    echo -e "${BLUE}Attempting to download $url with multiple connections...${NC}"
    aria2c -x 16 -s 16 -o $output_file $url --allow-overwrite=true --file-allocation=none --enable-color=true

    if [ $? -ne 0 ]; then
        echo -e "${RED}Multiple connection download failed. Retrying with a single connection...${NC}"
        aria2c -x 1 -s 1 -o $output_file $url --allow-overwrite=true --file-allocation=none --enable-color=true
        if [ $? -ne 0 ]; then
            echo -e "${RED}Download failed for $url using a single connection. Falling back to curl...${NC}"
            download_snapshot_with_curl $url $output_file
        fi
    else
        echo -e "${BLUE}Download successful using multiple connections.${NC}"
    fi
}

# Stop services if they are active
stop_service_if_exists() {
    local service_name=$1
    if systemctl is-active --quiet $service_name; then
        echo -e "${BLUE}Stopping $service_name...${NC}"
        sudo systemctl stop $service_name
    else
        echo -e "${RED}$service_name is not active or does not exist.${NC}"
    fi
}

# Stop services before extraction
stop_services() {
    stop_service_if_exists story.service
    stop_service_if_exists story-geth.service
}

# Backup priv_validator_state.json
backup_priv_validator_state() {
    echo -e "${BLUE}Backing up priv_validator_state.json...${NC}"
    cp $STORY_PRIV_VALIDATOR_STATE $STORY_BACKUP
}

# Clean up data directories
clean_data_directories() {
    echo -e "${BLUE}Cleaning up Story and Story Geth data directories...${NC}"
    rm -rf $GETH_CHAINDATA_DIR
    rm -rf $STORY_DATA_DIR
}

# Extract snapshots to their respective directories
extract_snapshots() {
    if [ -f "$STORY_SNAPSHOT_FILE" ]; then
        echo -e "${BLUE}Extracting Story snapshot...${NC}"
        lz4 -dc $STORY_SNAPSHOT_FILE | tar -x -C $STORY_DATA_EXTR_DIR
    else
        echo -e "${RED}Error: Story snapshot file not found!${NC}"
        exit 1
    fi

    if [ -f "$GETH_SNAPSHOT_FILE" ]; then
        echo -e "${BLUE}Extracting Geth snapshot...${NC}"
        lz4 -dc $GETH_SNAPSHOT_FILE | tar -x -C $GETH_CHAINDATA_EXTR_DIR
    else
        echo -e "${RED}Error: Geth snapshot file not found!${NC}"
        exit 1
    fi
}

# Restore priv_validator_state.json
restore_priv_validator_state() {
    echo -e "${BLUE}Restoring priv_validator_state.json...${NC}"
    cp $STORY_BACKUP $STORY_PRIV_VALIDATOR_STATE
}

# Restart services
restart_services() {
    echo -e "${BLUE}Restarting Story and Story-Geth services...${NC}"
    sudo systemctl start $STORY_SERVICE
    sudo systemctl start $GETH_SERVICE
}

# Main script execution
remove_existing_aria2_files
stop_services
backup_priv_validator_state
clean_data_directories
create_directories

# Download snapshots
download_snapshot $STORY_SNAPSHOT_URL $STORY_SNAPSHOT_FILE || exit 1
download_snapshot $GETH_SNAPSHOT_URL $GETH_SNAPSHOT_FILE || exit 1

# Extract snapshots
extract_snapshots

# Restore priv_validator_state.json and restart services
restore_priv_validator_state
restart_services

echo -e "${BLUE}Snapshot restoration and service restart complete!${NC}"
