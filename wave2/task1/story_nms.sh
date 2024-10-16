#!/bin/bash

# Variables for GitHub API
STORY_REPO="https://api.github.com/repos/piplabs/story/releases"
GETH_REPO="https://github.com/piplabs/story-geth.git"
INSTALL_DIR="/opt/story-node"
GETH_SERVICE_FILE="/etc/systemd/system/story-geth.service"
STORY_SERVICE_FILE="/etc/systemd/system/story.service"
DATA_DIR="${HOME}/.story"
GO_VERSION="1.21.13" # Specify the Go version you want to install

# Colors for screen prompts
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color (reset)

# Function definitions for colored printing and line separator
printGreen() { echo -e "\033[0;32m$1\033[0m"; }
printBlue() { echo -e "\033[0;34m$1\033[0m"; }
printRed() { echo -e "\033[0;31m$1\033[0m"; }
printLine() { echo "----------------------------------------"; }

# Function to display the ASCII Art Banner
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

                  _      
                 | |     
  _ __   ___   __| | ___ 
 | '_ \ / _ \ / _` |/ _ \
 | | | | (_) | (_| |  __/
 |_| |_|\___/ \__,_|\___|
                         
                         by https://moonli.me

EOF
}

# Install Go
install_go() {
    echo -e "${BLUE}Installing Go...${NC}"
    wget "https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz"
    sudo tar -C /usr/local -xzf "go$GO_VERSION.linux-amd64.tar.gz"
    echo '
    export GOPATH=$HOME/go
    export GOROOT=/usr/local/go
    export GOBIN=$GOPATH/bin
    export PATH=$PATH:/usr/local/go/bin:$GOBIN' >> ~/.profile
    . ~/.profile
    go version || { echo -e "${RED}Go installation failed.${NC}"; exit 1; }
    echo -e "${BLUE}Go installed successfully.${NC}"
}

# Install dependencies
install_dependencies() {
    echo -e "${BLUE}Installing necessary dependencies...${NC}"
    sudo apt-get update
    sudo apt-get install -y curl git make jq build-essential gcc unzip wget lz4 aria2 screen || {
        echo -e "${RED}Failed to install dependencies.${NC}"
        exit 1
    }
    install_go
    echo -e "${BLUE}Dependencies installed.${NC}"
    read -n1 -r -p "Press any key to continue..." key
}

# Get the latest 5 Story release version tags
get_story_versions() {
    local repo_url="$1"
    local release_data=$(curl -s "$repo_url" | jq -r '.[0:5] | .[] | .tag_name')
    
    if [ -z "$release_data" ]; then
        echo -e "${RED}Error: No Story versions found.${NC}" >&2
        exit 1
    fi
    echo "$release_data"
}

# Get the latest 5 Geth release version tags
get_geth_versions() {
    local repo_url="$1"
    local release_data=$(curl -s "$repo_url" | jq -r '.[0:5] | .[] | .tag_name')
    
    if [ -z "$release_data" ]; then
        echo -e "${RED}Error: No Geth versions found.${NC}" >&2
        exit 1
    fi
    echo "$release_data"
}

# Prompt the user to choose a Story version
choose_story_version() {
    echo -e "${BLUE}Available Story versions:${NC}"
    mapfile -t story_versions < <(get_story_versions "https://api.github.com/repos/piplabs/story/releases")

    if [ "${#story_versions[@]}" -eq 0 ]; then
        echo -e "${RED}No available Story versions.${NC}"
        exit 1
    fi

    # Display the available versions
    for i in "${!story_versions[@]}"; do
        echo "$((i + 1)). ${story_versions[$i]}"
    done

    read -p "Choose a Story version (1-5): " story_choice
    selected_story_version="${story_versions[$((story_choice - 1))]}"
    echo "Selected Story version: $selected_story_version"
}

# Prompt the user to choose a Geth version
choose_geth_version() {
    echo -e "${BLUE}Available Geth versions:${NC}"
    mapfile -t geth_versions < <(get_geth_versions "https://api.github.com/repos/piplabs/story-geth/releases")

    if [ "${#geth_versions[@]}" -eq 0 ]; then
        echo -e "${RED}No available Geth versions.${NC}"
        exit 1
    fi

    # Display the available versions
    for i in "${!geth_versions[@]}"; do
        echo "$((i + 1)). ${geth_versions[$i]}"
    done

    read -p "Choose a Geth version (1-5): " geth_choice
    selected_geth_version="${geth_versions[$((geth_choice - 1))]}"
    echo "Selected Geth version: $selected_geth_version"
}

# Clone and build Story and Geth binaries
build_story_and_geth() {
    echo -e "${BLUE}Building Story and Geth...${NC}"

    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # Download Story
    STORY_URL=$(curl -s "https://api.github.com/repos/piplabs/story/releases/tags/$selected_story_version" | jq -r '.body' | grep -Eo 'https://[^\"]+story-linux-amd64[^\"]+\.tar\.gz')
    # Proceed with downloading and installing the selected versions
    echo -e "${BLUE}Installing Story...${NC}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    wget "$STORY_URL" -O story.tar.gz || { echo -e "${RED}Failed to download Story binary.${NC}"; exit 1; }
    tar --strip-components=1 -xzf story.tar.gz -C "$INSTALL_DIR" || { echo -e "${RED}Failed to extract Story binary.${NC}"; exit 1; }

    # Clone and build Story-Geth
    echo -e "${BLUE}Installing Story Geth...${NC}"
    git clone "$GETH_REPO" story-geth || { echo -e "${RED}Failed to clone Geth repository.${NC}"; exit 1; }
    cd story-geth
    git checkout "$selected_geth_version" || { echo -e "${RED}Failed to checkout Geth version.${NC}"; exit 1; }
    go build -o geth ./cmd/geth || { echo -e "${RED}Failed to build Geth.${NC}"; exit 1; }
    mv geth "$INSTALL_DIR"/geth
    cd ..

    echo -e "${BLUE}Story and Geth built successfully.${NC}"
}

# Install Story node
install_node() {
    echo -e "${BLUE}Fetching available Story and Story Geth releases...${NC}"

    # Fetch and allow the user to choose a version of Story and Geth
    choose_story_version
    choose_geth_version

    # Build Story and Geth from source
    build_story_and_geth
    
    initialize_story
    download_and_extract_snapshot
}

# Prompt user for moniker and initialize Story
initialize_story() {
    while [[ -z "$moniker_name" ]]; do
        read -p "Please enter your moniker name (cannot be empty): " moniker_name
        if [[ -z "$moniker_name" ]]; then
            echo -e "${RED}Moniker cannot be empty. Try again.${NC}"
        fi
    done

    echo -e "${BLUE}Initializing Story with moniker: $moniker_name...${NC}"
    $INSTALL_DIR/$STORY_DIR/story init --network iliad --moniker "$moniker_name"

    if [ $? -eq 0 ]; then
        echo -e "${BLUE}Story has been initialized successfully with the moniker: $moniker_name.${NC}"

        # Fetch seeds and update config.toml
        PEERS=$(curl -sS https://story-cosmos-testnet-rpc.tech-coha05.xyz/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)
        echo -e "${BLUE}Updating seeds in config.toml with: $PEERS${NC}"
        sed -i.bak -e "s/^seeds *=.*/seeds = \"$PEERS\"/" "$DATA_DIR/story/config/config.toml"
        echo -e "${BLUE}Seeds updated in config.toml.${NC}"

    else
        echo -e "${RED}Error: Story initialization failed.${NC}"
        exit 1
    fi
}

# Download and extract the snapshot
download_and_extract_snapshot() {
    echo -e "${BLUE}Creating necessary directory structure for snapshot...${NC}"

    # Create the required directory structure if it doesn't exist
    SNAPSHOT_DIR="${HOME}/.story/geth/iliad/geth"
    sudo mkdir -p "$SNAPSHOT_DIR"

  echo "Story Snapshot Automation Tool (adapted from https://itrocket.net/api/testnet/story/autosnap/)"
sleep 1

# Defining variables for type and project
type=testnet
project=story
rootUrl=server-3.itrocket.net
storyPath=$HOME/.story/story
gethPath=$HOME/.story/geth/iliad/geth
# Variables for file servers and parent RPCs
FILE_SERVERS=(
  "https://server-3.itrocket.net/testnet/story/.current_state.json"
  "https://server-1.itrocket.net/testnet/story/.current_state.json"
  "https://server-5.itrocket.net/testnet/story/.current_state.json"
)
RPC_COMBINED_FILE="https://server-3.itrocket.net/testnet/story/.rpc_combined.json"
PARENT_RPC="https://story-testnet-rpc.itrocket.net"
MAX_ATTEMPTS=3
TEST_FILE_SIZE=50000000  # File size in bytes for download speed check

# Array to store available snapshots
SNAPSHOTS=()

# Function to get the server number from the URL
get_server_number() {
  local URL=$1
  echo "$URL" | grep -oP 'server-\K[0-9]+'
}

# Function to prompt user to continue or exit
ask_to_continue() {
  read -p "$(printYellow 'Do you want to continue anyway? (y/n): ')" choice
  if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
    printRed "Exiting script."
    exit 1
  fi
}

# Function to fetch snapshot data from the server
fetch_snapshot_data() {
  local URL=$1
  local ATTEMPT=0
  local DATA=""

  while (( ATTEMPT < MAX_ATTEMPTS )); do
    DATA=$(curl -s --max-time 5 "$URL")
    if [[ -n "$DATA" ]]; then
      break
    else
      ((ATTEMPT++))
      sleep 1
    fi
  done

  echo "$DATA"
}

# Function to get the second Parent RPC from the file
get_second_parent_rpc() {
  local RPC_RESPONSE=$(curl -s --max-time 5 "$RPC_COMBINED_FILE")
  if [[ -n "$RPC_RESPONSE" ]]; then
    echo $(echo "$RPC_RESPONSE" | jq -r 'to_entries[0].key')
  else
    echo ""
  fi
}

# Function to get the maximum block height from parent RPCs
get_parent_block_height() {
  local MAX_PARENT_HEIGHT=0
  for ((ATTEMPTS=0; ATTEMPTS<MAX_ATTEMPTS; ATTEMPTS++)); do

    local PARENT_HEIGHTS=()
    for RPC in "$PARENT_RPC" "$SECOND_PARENT_RPC"; do
      if [[ -n "$RPC" ]]; then
        local RESPONSE=$(curl -s --max-time 3 "$RPC/status")
        local HEIGHT=$(echo "$RESPONSE" | jq -r '.result.sync_info.latest_block_height' | tr -d '[:space:]')
        if [[ $HEIGHT =~ ^[0-9]+$ ]]; then
          PARENT_HEIGHTS+=("$HEIGHT")
        fi
      fi
    done

    if [[ ${#PARENT_HEIGHTS[@]} -gt 0 ]]; then
      MAX_PARENT_HEIGHT=$(printf "%s\n" "${PARENT_HEIGHTS[@]}" | sort -nr | head -n1)
      break
    fi

    sleep 5
  done
  echo $MAX_PARENT_HEIGHT
}

# Function to get block time by height
get_block_time() {
  local HEIGHT=$1
  local RPC_URLS=("$PARENT_RPC" "$SECOND_PARENT_RPC")
  for RPC_URL in "${RPC_URLS[@]}"; do
    if [[ -n "$RPC_URL" ]]; then
      local RESPONSE=$(curl -s --max-time 5 "$RPC_URL/block?height=$HEIGHT")
      if [[ -n "$RESPONSE" ]]; then
        local BLOCK_TIME=$(echo "$RESPONSE" | jq -r '.result.block.header.time')
        if [[ "$BLOCK_TIME" != "null" ]]; then
          echo "$BLOCK_TIME"
          return 0
        fi
      fi
    fi
  done
  echo ""
}

# Function to measure download speed from a specific server
measure_download_speed() {
  local SERVER_URL=$1
  local SNAPSHOT_NAME=$2
  local TOTAL_SPEED=0
  local NUM_TESTS=3

  for ((i=1; i<=NUM_TESTS; i++)); do
    local TMP_FILE=$(mktemp)
    local FULL_URL="$SERVER_URL/${type}/${project}/$SNAPSHOT_NAME"

    local START_TIME=$(date +%s.%N)
    curl -s --max-time 10 --range 0-$TEST_FILE_SIZE -o "$TMP_FILE" "$FULL_URL"
    local END_TIME=$(date +%s.%N)

    local DURATION=$(echo "$END_TIME - $START_TIME" | bc -l)
    if (( $(echo "$DURATION > 0" | bc -l) )); then
      local SPEED=$(echo "scale=2; $TEST_FILE_SIZE / $DURATION" | bc -l)
      TOTAL_SPEED=$(echo "$TOTAL_SPEED + $SPEED" | bc -l)
    fi

    rm -f "$TMP_FILE"
  done

  if (( $(echo "$TOTAL_SPEED > 0" | bc -l) )); then
    local AVERAGE_SPEED=$(echo "scale=2; $TOTAL_SPEED / $NUM_TESTS" | bc -l)
  else
    local AVERAGE_SPEED=0
  fi

  echo "$AVERAGE_SPEED"
}

# Function to calculate estimated download time
calculate_estimated_time() {
  local FILE_SIZE_BYTES=$1
  local DOWNLOAD_SPEED=$2  # In bytes per second
  if (( $(echo "$DOWNLOAD_SPEED > 0" | bc -l) )); then
    local TIME_SECONDS=$(echo "scale=2; $FILE_SIZE_BYTES / $DOWNLOAD_SPEED" | bc -l)
    local TIME_SECONDS_INT=$(printf "%.0f" "$TIME_SECONDS")
    local TIME_HOURS=$((TIME_SECONDS_INT / 3600))
    local TIME_MINUTES=$(( (TIME_SECONDS_INT % 3600) / 60 ))
    echo "${TIME_HOURS}h ${TIME_MINUTES}m"
  else
    echo "N/A"
  fi
}

# Function to display snapshot information
process_snapshot_info() {
  local SERVER_NAME=$1
  local DATA=$2
  local PARENT_BLOCK_HEIGHT=$3
  local SERVER_URL=$4

  if [[ -n "$DATA" ]]; then
    local SNAPSHOT_NAME=$(echo "$DATA" | jq -r '.snapshot_name')
    local GETH_NAME=$(echo "$DATA" | jq -r '.snapshot_geth_name')
    local SNAPSHOT_HEIGHT=$(echo "$DATA" | jq -r '.snapshot_height')
    local SNAPSHOT_SIZE=$(echo "$DATA" | jq -r '.snapshot_size')
    local GETH_SIZE=$(echo "$DATA" | jq -r '.geth_snapshot_size')
    local INDEXER=$(echo "$DATA" | jq -r '.indexer')

    local SNAPSHOT_SIZE_BYTES=$(echo "$SNAPSHOT_SIZE" | sed 's/G//')000000000
    local GETH_SIZE_BYTES=$(echo "$GETH_SIZE" | sed 's/G//')000000000
    local TOTAL_SIZE_BYTES=$(($SNAPSHOT_SIZE_BYTES + $GETH_SIZE_BYTES))

    local TOTAL_SIZE_GB_NUM=$(echo "$TOTAL_SIZE_BYTES / 1000000000" | bc)
    local TOTAL_SIZE_GB="${TOTAL_SIZE_GB_NUM}G"

    local DOWNLOAD_SPEED=$(measure_download_speed "$SERVER_URL" "$SNAPSHOT_NAME")
    local ESTIMATED_TIME=$(calculate_estimated_time "$TOTAL_SIZE_BYTES" "$DOWNLOAD_SPEED")

    local BLOCKS_BEHIND=$((PARENT_BLOCK_HEIGHT - SNAPSHOT_HEIGHT))

    local SNAPSHOT_TYPE="pruned"
    if [[ "$INDEXER" == "kv" ]]; then
      SNAPSHOT_TYPE="archive"
    fi

    # Get block time for SNAPSHOT_HEIGHT
    local BLOCK_TIME=$(get_block_time "$SNAPSHOT_HEIGHT")
    local SNAPSHOT_AGE=""
    if [[ -n "$BLOCK_TIME" ]]; then
      local BLOCK_TIME_EPOCH=$(date -d "$BLOCK_TIME" +%s)
      local CURRENT_TIME_EPOCH=$(date +%s)
      local TIME_DIFF=$((CURRENT_TIME_EPOCH - BLOCK_TIME_EPOCH))
      local TIME_DIFF_HOURS=$((TIME_DIFF / 3600))
      local TIME_DIFF_MINUTES=$(((TIME_DIFF % 3600) / 60))
      SNAPSHOT_AGE="${TIME_DIFF_HOURS}h ${TIME_DIFF_MINUTES}m ago"
    else
      SNAPSHOT_AGE="N/A"
    fi

    local SERVER_NUMBER=$(get_server_number "$SERVER_URL")
    SNAPSHOTS+=("$SERVER_NUMBER|$SNAPSHOT_TYPE|$SNAPSHOT_HEIGHT|$BLOCKS_BEHIND|$SNAPSHOT_AGE|$TOTAL_SIZE_GB|$SNAPSHOT_SIZE|$GETH_SIZE|$ESTIMATED_TIME|$SERVER_URL|$SNAPSHOT_NAME|$GETH_NAME")
  fi
}

# Function to install the selected snapshot
install_snapshot() {
  local SNAPSHOT_NAME=$1
  local GETH_NAME=$2
  local SERVER_URL=$3

  echo "Installing snapshot from $SERVER_URL:"
  echo "Snapshot: $SNAPSHOT_NAME"
  echo "Geth Snapshot: $GETH_NAME"

  printLine
  printGreen "2.  Backing up priv_validator_state.json..." && sleep 1
  if cp "$storyPath/data/priv_validator_state.json" "$storyPath/priv_validator_state.json.backup"; then
    printBlue "done"
  else
    printRed "Failed to backup priv_validator_state.json"
    ask_to_continue
  fi

  printLine
  printGreen "3.  Removing old data and unpacking Story snapshot..." && sleep 1
  if rm -rf "$storyPath/data"; then
    printBlue "Old data removed"
  else
    printRed "Failed to remove old data"
    ask_to_continue
  fi

  printLine
  if curl "$SERVER_URL/${type}/${project}/$SNAPSHOT_NAME" | lz4 -dc - | tar -xf - -C "$storyPath"; then
    printBlue "Snapshot unpacked"
  else
    printRed "Failed to unpack Story snapshot"
    ask_to_continue
  fi

  printLine
  printGreen "4.  Restoring priv_validator_state.json..." && sleep 1
  if mv "$storyPath/priv_validator_state.json.backup" "$storyPath/data/priv_validator_state.json"; then
    printBlue "done"
  else
    printRed "Failed to restore priv_validator_state.json"
    ask_to_continue
  fi

  printLine
  printGreen "5.  Deleting geth data and unpacking geth snapshot..." && sleep 1
  if rm -rf "$gethPath/chaindata"; then
    printBlue "Geth data deleted"
  else
    printRed "Failed to delete geth data"
    ask_to_continue
  fi

  printLine
  if curl "$SERVER_URL/${type}/${project}/$GETH_NAME" | lz4 -dc - | tar -xf - -C "$gethPath"; then
    printBlue "Geth snapshot unpacked"
  else
    printRed "Failed to unpack geth snapshot"
    ask_to_continue
  fi

}

# Function to display spinner
spinner() {
  local delay=0.1
  local spinstr='|/-\'
  while [ -f /tmp/snapshot_processing ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\r"
  done
}

printGreen "1. Searching snapshots and calculating parameters..." && sleep 1
printLine

# Create flag file to indicate process
touch /tmp/snapshot_processing
spinner &
SPINNER_PID=$!

# Fetch second Parent RPC
SECOND_PARENT_RPC=$(get_second_parent_rpc)

# Get block heights from Parent RPCs
MAX_PARENT_HEIGHT=$(get_parent_block_height)

# Check for snapshot data on servers
for FILE_SERVER in "${FILE_SERVERS[@]}"; do
  DATA=$(fetch_snapshot_data "$FILE_SERVER")
  if [[ -n "$DATA" ]]; then
    SERVER_URL=$(echo "$FILE_SERVER" | sed "s|/${type}/${project}/.current_state.json||")
    SERVER_NUMBER=$(get_server_number "$SERVER_URL")
    process_snapshot_info "$SERVER_NUMBER" "$DATA" "$MAX_PARENT_HEIGHT" "$SERVER_URL"
  fi
done

# Remove flag file and stop spinner
rm -f /tmp/snapshot_processing
wait $SPINNER_PID 2>/dev/null
echo

# If no servers were available
if [[ ${#SNAPSHOTS[@]} -eq 0 ]]; then
  echo "Sorry, snapshot is not available at the moment. Please try later."
  exit 1
fi

# Display available snapshots with information
printGreen "Available snapshots:"
printLine
for i in "${!SNAPSHOTS[@]}"; do
  IFS='|' read -r SERVER_NUMBER SNAPSHOT_TYPE SNAPSHOT_HEIGHT BLOCKS_BEHIND SNAPSHOT_AGE TOTAL_SIZE_GB SNAPSHOT_SIZE GETH_SIZE ESTIMATED_TIME SERVER_URL SNAPSHOT_NAME GETH_NAME <<< "${SNAPSHOTS[$i]}"

  # Display server header with Estim. Time
  echo -ne "Server $SERVER_NUMBER: $SNAPSHOT_TYPE | "
  echo -e "${RED}Estim. Time: $ESTIMATED_TIME${NC}"

  # Form a line of info, separated by '|'
  INFO_LINE="$SNAPSHOT_HEIGHT ($SNAPSHOT_AGE, $BLOCKS_BEHIND blocks ago) | Size: $TOTAL_SIZE_GB (${project} $SNAPSHOT_SIZE, Geth $GETH_SIZE)"

  # Display snapshot information in green
  printGreen "$INFO_LINE"

  # Display server URL in blue
  printBlue "$SERVER_URL"

  printLine
done

# Read user choice
echo -ne "${GREEN}Choose a server to install snapshot and press enter ${NC}"
echo -ne "(${SNAPSHOTS[*]//|*}): "
read -r CHOICE

# Check user choice and install the corresponding snapshot
VALID_CHOICE=false
for i in "${!SNAPSHOTS[@]}"; do
  IFS='|' read -r SERVER_NUMBER SNAPSHOT_TYPE SNAPSHOT_HEIGHT BLOCKS_BEHIND SNAPSHOT_AGE TOTAL_SIZE_GB SNAPSHOT_SIZE GETH_SIZE ESTIMATED_TIME SERVER_URL SNAPSHOT_NAME GETH_NAME <<< "${SNAPSHOTS[$i]}"
  if [[ "$CHOICE" == "$SERVER_NUMBER" ]]; then
    install_snapshot "$SNAPSHOT_NAME" "$GETH_NAME" "$SERVER_URL"
    VALID_CHOICE=true
    break
  fi
done

if ! $VALID_CHOICE; then
  printRed "Invalid choice. Exiting."
  exit 1
fi

}

# Create systemd service for Geth
setup_geth_service() {
    echo -e "${BLUE}Creating systemd service for Story Geth...${NC}"

    sudo tee "$GETH_SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=$INSTALL_DIR/geth --iliad --syncmode full \\
    --http --http.api eth,net,web3,engine \\
    --http.vhosts '*' --http.addr 127.0.0.1 --http.port 8545 \\
    --ws --ws.api eth,web3,net,txpool --ws.addr 127.0.0.1 --ws.port 8546 \\
    --bootnodes enode://a86b76eb7171eb68c4495e1fbad292715eee9b77a34ffa5cf39e40cc9047e1c41e01486d1e31428228a1350b0f870bcd3b6c5d608ba65fe7b7fcba715a78eeb8@story-geth.mandragora.io:30303
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable story-geth.service
    sudo systemctl start story-geth.service

    echo -e "${BLUE}Story Geth service has been started.${NC}"
    read -n1 -r -p "Press any key to continue..." key
}

# Function to create systemd service for Story
setup_story_service() {
    echo -e "${BLUE}Creating systemd service for Story...${NC}"

    sudo tee "$STORY_SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=$INSTALL_DIR/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable story.service
    sudo systemctl start story.service

    echo -e "${BLUE}Story service has been started.${NC}"
    read -n1 -r -p "Press any key to continue..." key
}

# Check node status
check_status() {
    echo -e "${BLUE}Checking local Story node status...${NC}"
    
    systemctl is-active --quiet story.service || { echo -e "${RED}Story service is not running.${NC}"; exit 1; }

    local_status=$(curl -s localhost:26657/status | jq '.result.sync_info | {latest_block_height, catching_up}')
    local_block_height=$(echo "$local_status" | jq -r '.latest_block_height')
    local_catching_up=$(echo "$local_status" | jq -r '.catching_up')

    echo -e "${BLUE}Local Node Block Height: ${local_block_height}${NC}"
    echo -e "${BLUE}Local Node Catching Up: ${local_catching_up}${NC}"

    RPC_LIST=("https://story-cosmos-testnet-rpc.tech-coha05.xyz" "https://story-testnet-rpc.itrocket.net")
    
    for rpc in "${RPC_LIST[@]}"; do
        echo -e "${BLUE}Checking status for RPC: $rpc${NC}"
        
        remote_block_height=$(curl -s "$rpc/status" | jq -r '.result.sync_info.latest_block_height')

        echo -e "${BLUE}Remote Node Block Height ($rpc): $remote_block_height${NC}"

        block_diff=$((local_block_height - remote_block_height))
        block_diff=${block_diff#-}

        if [[ "$block_diff" -le 10 ]]; then
            echo -e "${BLUE}Block heights are the same: $local_block_height${NC}"
        else
            echo -e "\033[0;31mBlock heights are NOT the same! Local: $local_block_height, Remote: $remote_block_height\033[0m"
        fi

        echo "----------------------------------------"
    done
    
    read -n1 -r -p "Press any key to continue..." key
}

# View Story Geth logs
view_geth_logs() {
    echo -e "${BLUE}Viewing Story Geth logs...${NC}"
    sudo journalctl -u story-geth.service -f
}

# View Story Consensus Client logs
view_story_logs() {
    echo -e "${BLUE}Viewing Story Consensus Client logs...${NC}"
    sudo journalctl -u story.service -f
}

# Stop the Story Geth service
stop_geth_service() {
    echo -e "${BLUE}Stopping Story Geth service...${NC}"
    sudo systemctl stop story-geth.service
}

# Stop the Story service
stop_story_service() {
    echo -e "${BLUE}Stopping Story service...${NC}"
    sudo systemctl stop story.service
}

# Restart the Story Geth service
restart_geth_service() {
    echo -e "${BLUE}Restarting Story Geth service...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl restart story-geth.service
}

# Restart the Story service
restart_story_service() {
    echo -e "${BLUE}Restarting Story service...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl restart story.service
}

# Remove services and data
remove_services() {
    echo -e "${BLUE}Removing Story services and data...${NC}"
    sudo systemctl stop story-geth.service story.service
    sudo systemctl disable story-geth.service story.service
    sudo rm "$GETH_SERVICE_FILE" "$STORY_SERVICE_FILE"
    sudo rm -rf /usr/local/go
    sudo systemctl daemon-reload
    rm -rf "$INSTALL_DIR" "$DATA_DIR"
    echo -e "${BLUE}Services and data have been removed.${NC}"
    read -n1 -r -p "Press any key to continue..." key
}

# Main menu function
main_menu() {
    clear
    display_banner
    echo -e "${BLUE}Story Node Management Script${NC}"
    echo "============================"
    echo "1. Install Dependencies"
    echo "2. Install Node (Download and Install Story and Story Geth, Initialize Story, Add Seeds, Download and Unpack Snapshots)"
    echo "3. Setup Systemd Services and Start Node"
    echo "4. Check Node Status"
    echo "5. View Story Geth Logs"
    echo "6. View Story Consensus Client Logs"
    echo "7. Stop Story Geth Service"
    echo "8. Stop Story Service"
    echo "9. Restart Story Geth Service"
    echo "10. Restart Story Service"
    echo "11. Remove Services and Data"
    echo "12. Exit"
    echo ""
    read -p "Choose an option [1-12]: " option

    case $option in
        1)
            install_dependencies
            ;;
        2)
            install_node
            ;;
        3)
            setup_geth_service
            setup_story_service
            ;;
        4)
            check_status
            ;;
        5)
            view_geth_logs
            ;;
        6)
            view_story_logs
            ;;
        7)
            stop_geth_service
            ;;
        8)
            stop_story_service
            ;;
        9)
            restart_geth_service
            ;;
        10)
            restart_story_service
            ;;
        11)
            remove_services
            ;;
        12)
            echo -e "${BLUE}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose between 1-12.${NC}"
            ;;
    esac
}

# Loop to keep the script running until the user chooses to exit
while true; do
    main_menu
done
