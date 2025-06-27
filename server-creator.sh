#!/bin/bash
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        case $ID in
            "ubuntu"|"debian"|"linuxmint"|"pop"|"kubuntu"|"xubuntu"|"elementary"|"zorin"|"ubuntu-mate"|"neon"|"kali"|"ubuntu-studio")
                DISTRO="debian-based"
                ;;
            "fedora")
                DISTRO="fedora"
                ;;
            "opensuse-tumbleweed"|"opensuse-leap")
                DISTRO="opensuse"
                ;;
            "manjaro"|"arch"|"endeavouros")
                DISTRO="arch"
                ;;
            *)
                echo "Unsupported distribution: $ID"
                exit 1
                ;;
        esac
    else
        echo "Unsupported distribution"
        exit 1
    fi
}
detect_distro

install_dependencies() {
    for dep in jq whiptail wget curl; do
        if ! command -v "$dep" &> /dev/null; then
            echo "$dep is not installed. Installing..."
            case "$DISTRO" in
                "debian-based")
                    sudo apt-get update
                    sudo apt-get install -y "$dep"
                    ;;
                "fedora")
                    sudo dnf install -y "$dep"
                    ;;
                "opensuse")
                    sudo zypper install -y "$dep"
                    ;;
                "arch")
                    sudo pacman -Syu --noconfirm "$dep"
                    ;;
                *)
                    echo "Unsupported distribution: $DISTRO"
                    exit 1
                    ;;
            esac
        fi
    done

    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing..."
        case "$DISTRO" in
            "debian-based")
                sudo apt-get update
                sudo apt-get install -y docker.io
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker $USER
                ;;
            "fedora")
                sudo dnf install -y docker
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker $USER
                ;;
            "opensuse")
                sudo zypper install -y docker
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker $USER
                ;;
            "arch")
                sudo pacman -Syu --noconfirm docker
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker $USER
                ;;
            *)
                echo "Unsupported distribution: $DISTRO"
                exit 1
                ;;
        esac
        echo "Docker installed. You may need to log out and back in for group changes to take effect."
    fi
}

install_dependencies

mem=$(free -h | grep -i mem | awk '{print int($2 + 0.5)}')

# Check dependencies
for dep in jq whiptail wget; do
    if ! command -v "$dep" &> /dev/null; then
        echo "Please install $dep first (apt/yum install $dep)"
        exit 1
    fi
done

# Function to choose a Minecraft version using Mojang's version manifest.
choose_minecraft_version() {
    MANIFEST=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json)
    RELEASES=$(echo "$MANIFEST" | jq -r '.versions[] | select(.type == "release") | "\(.id) \(.url)"')
    SNAPSHOTS=$(echo "$MANIFEST" | jq -r '.versions[] | select(.type == "snapshot") | "\(.id) \(.url)"')

    VERSION_TYPE=$(whiptail --title "Minecraft Server" \
        --menu "Choose version type:" 15 50 4 \
        "1" "Release Versions" \
        "2" "Snapshot Versions" \
        3>&1 1>&2 2>&3)
    if [ "$VERSION_TYPE" == "1" ]; then
         VERSIONS_LIST="$RELEASES"
         TYPE="Release"
    else
         VERSIONS_LIST="$SNAPSHOTS"
         TYPE="Snapshot"
    fi

    local menu_items=()
    while read -r line; do
         version_id=$(echo "$line" | cut -d' ' -f1)
         menu_items+=("$version_id" "")
    done <<< "$VERSIONS_LIST"

    SELECTED_VERSION=$(whiptail --title "Minecraft $TYPE Versions" \
         --menu "Choose a version:" 20 60 10 "${menu_items[@]}" \
         3>&1 1>&2 2>&3)
    [ -z "$SELECTED_VERSION" ] && return 1

    # Extract the download URL for later use (for Vanilla server downloads)
    SELECTED_URL=$(echo "$VERSIONS_LIST" | grep "^$SELECTED_VERSION " | cut -d' ' -f2)

    MC_VERSION="$SELECTED_VERSION"
    MC_VERSION_URL="$SELECTED_URL"
    return 0
}

# Vanilla server installation using the chosen Minecraft version.
install_vanilla() {
    choose_minecraft_version || return 1

    # Get the server download URL from Mojang's version details.
    SERVER_URL=$(curl -s "$MC_VERSION_URL" | jq -r '.downloads.server.url')

    # Store the URL for Dockerfile use
    SERVER_DOWNLOAD_URL="$SERVER_URL"

    whiptail --title "Downloading" --infobox "Downloading $MC_VERSION server.jar..." 8 50
    if wget -q -O server.jar "$SERVER_URL"; then
        echo "Download Success"
    else
        whiptail --title "Error" --msgbox "Failed to download $MC_VERSION server.jar!" 8 50
    fi
}

# Fabric server installation using the same UI for Minecraft version selection.
install_fabric() {
    choose_minecraft_version || return 1

    # Automatically obtain the default Fabric loader version.
    LOADER_VERSION=$(curl -s https://meta.fabricmc.net/v2/versions/loader | jq -r '.[] | select(.stable == true) | .version' | head -n 1)
    FABRIC_INSTALLER_VERSION="1.0.1"
    DOWNLOAD_URL="https://meta.fabricmc.net/v2/versions/loader/${MC_VERSION}/${LOADER_VERSION}/${FABRIC_INSTALLER_VERSION}/server/jar"

    # Store the URL for Dockerfile use
    SERVER_DOWNLOAD_URL="$DOWNLOAD_URL"
}

# Forge server installation using the same Minecraft version UI.
install_forge() {
    #Work in progress 
    choose_minecraft_version || return 1

}

# NeoForge server installation (update the URL as needed).
install_neoforge() {
    #Work in progress
    choose_minecraft_version || return 1
}

# Main menu for server type selection.
SERVER_TYPE=$(whiptail --title "Minecraft Server Installer" \
    --menu "Choose server type:" 15 50 4 \
    "Vanilla" "" \
    "Fabric" "" \
    3>&1 1>&2 2>&3)
[ -z "$SERVER_TYPE" ] && exit 0

case $SERVER_TYPE in
    "Vanilla")
         install_vanilla
         ;;
    "Fabric")
         install_fabric
         ;;
    "Forge")
         install_forge
         ;;
    "NeoForge")
         install_neoforge
         ;;
    *)
         whiptail --title "Error" --msgbox "Unknown server type selected" 8 50
         exit 1
         ;;
esac

if whiptail --yesno "Do you agree with the Minecraft EULA?" 10 50 --title "EULA Agreement"; then
    dt=$(date '+%d/%m/%Y %H:%M:%S');
    echo "#$dt 
eula=true" > eula.txt
else
    echo "You must agree to the EULA to proceed."
    exit 1
fi

DIFFICULTY=$(whiptail --title "Difficulty" \
    --menu "Choose server type:" 15 50 4 \
    "Peaceful" "" \
    "Easy" "" \
    "Normal" "" \
    "Hard" "" \
    "Hardcore" "" \
    3>&1 1>&2 2>&3)
[ -z "$DIFFICULTY" ] && exit 0
distance=$(whiptail --inputbox "Enter the render distance that you want:" 10 50 --title "Render distance" 3>&1 1>&2 2>&3)
if [ -z "$distance" ]; then
    distance=10
fi
if [ "$DIFFICULTY" == "Hardcore" ]; then 
    gamemode=hardcore
    difficulty=hard
    hardcore=true
else
    gamemode=$(whiptail --title "Gamemode" \
        --menu "Choose your gamemode:" 15 50 4 \
        "Survival" "" \
        "Creative" "" \
        3>&1 1>&2 2>&3)
    [ -z "$gamemode" ] && exit 0
fi
port=$(whiptail --inputbox "Enter the port that you want leave empty for default" 10 50 --title "Server port" 3>&1 1>&2 2>&3)
if [ -z "$port" ]; then
    port=25565
fi
name=$(whiptail --inputbox "Enter a name for your server" 10 50 --title "Server name" 3>&1 1>&2 2>&3)
if [ -z "$name" ]; then
   name="a very cool minecraft server"
fi
seed=$(whiptail --inputbox "Enter a seed leave empty for random" 10 50 --title "Server seed" 3>&1 1>&2 2>&3)
if whiptail --yesno "Do you want to start your server at system startup?" 10 50 --title "Confirmation"; then
    autostart=true
else 
    autostart=false
fi

if whiptail --yesno "Do you want to start as soon the minecraft server when the script is done" 10 50 --title "Confirmation"; then
    start=true
else 
    start=false
fi

echo "#Minecraft server properties
allow-flight=true
allow-nether=true
broadcast-console-to-ops=true
broadcast-rcon-to-ops=true
difficulty=${difficulty}
enable-command-block=false
enable-jmx-monitoring=false
enable-query=false
enable-rcon=false
enable-status=true
enforce-secure-profile=true
enforce-whitelist=false
entity-broadcast-range-percentage=100
force-gamemode=false
function-permission-level=2
gamemode=${gamemode}
generate-structures=true
generator-settings={}
hardcore=${hardcore}
hide-online-players=false
initial-disabled-packs=
initial-enabled-packs=vanilla
level-name=world
level-seed=${seed}
level-type=minecraft:normal
max-chained-neighbor-updates=1000000
max-players=20
max-tick-time=60000
max-world-size=29999984
motd=${name}
network-compression-threshold=256
online-mode=true
op-permission-level=4
player-idle-timeout=0
prevent-proxy-connections=false
pvp=true
query.port=25565
rate-limit=0
rcon.password=
rcon.port=25575
require-resource-pack=false
resource-pack=
resource-pack-prompt=
resource-pack-sha1=
server-ip=
server-port=${port}
simulation-distance=${distance}
spawn-animals=true
spawn-monsters=true
spawn-npcs=true
spawn-protection=0
sync-chunk-writes=true
text-filtering-config=
use-native-transport=true
view-distance=${distance}
white-list=false" > server.properties

# Create Dockerfile
cat > Dockerfile <<EOF
FROM openjdk:21-jdk-slim

RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

WORKDIR /minecraft

COPY eula.txt .
COPY server.properties .

RUN wget -O server.jar "${SERVER_DOWNLOAD_URL}"

EXPOSE ${port}

CMD ["java", "-Xmx${mem}G", "-Xms${mem}G", "-jar", "server.jar", "nogui"]
EOF

# Build Docker image
echo "Building Docker image..."
sudo docker build -t minecraft-server .

# Function to find unique container name
find_unique_container_name() {
    local base_name="minecraft-server-container"
    local container_name="$base_name"
    local counter=1
    
    while sudo docker ps -a --filter "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; do
        container_name="${base_name}-${counter}"
        counter=$((counter + 1))
    done
    
    echo "$container_name"
}

# Get unique container name
CONTAINER_NAME=$(find_unique_container_name)
echo "Using container name: $CONTAINER_NAME"

# Create and start container with restart policy
echo "Starting Minecraft server container..."
if [ "$autostart" == "true" ]; then
    RESTART_POLICY="--restart always"
else
    RESTART_POLICY=""
fi

sudo docker run -d \
    --name "$CONTAINER_NAME" \
    -p ${port}:${port} \
    -v minecraft-data-$(echo "$CONTAINER_NAME" | sed 's/minecraft-server-container//'):/minecraft/world \
    $RESTART_POLICY \
    minecraft-server

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -f eula.txt server.properties Dockerfile

if [ "$start" == "true" ]; then
    echo "Minecraft server is starting in Docker container..."
    echo "Container name: $CONTAINER_NAME"
    echo "Port: ${port}"
    echo "To view logs: docker logs -f $CONTAINER_NAME"
    echo "To stop: docker stop $CONTAINER_NAME"
else
    echo "Minecraft server container created but not started."
    echo "To start: docker start $CONTAINER_NAME"
fi

echo "Setup complete!"

# Create backup script
cat > backup-minecraft.sh <<'EOF'
#!/bin/bash

# Function to list all minecraft containers
list_minecraft_containers() {
    sudo docker ps -a --filter "name=minecraft-server-container" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Function to get container names for selection
get_container_names() {
    sudo docker ps -a --filter "name=minecraft-server-container" --format "{{.Names}}"
}

# Function to backup a specific container
backup_container() {
    local container_name="$1"
    local backup_date=$(date +"%Y%m%d_%H%M%S")
    local backup_filename="${container_name}_backup_${backup_date}.zip"
    
    echo "Backing up container: $container_name"
    
    # Stop the container temporarily for consistent backup
    local was_running=false
    if sudo docker ps --filter "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
        was_running=true
        echo "Stopping container for backup..."
        sudo docker stop "$container_name"
    fi
    
    # Create temporary directory for backup
    local temp_dir=$(mktemp -d)
    
    # Copy world data from volume
    local volume_name=$(sudo docker inspect "$container_name" | jq -r '.[0].Mounts[] | select(.Destination == "/minecraft/world") | .Name')
    if [ "$volume_name" != "null" ] && [ -n "$volume_name" ]; then
        echo "Copying world data..."
        sudo docker run --rm -v "$volume_name":/source -v "$temp_dir":/backup alpine sh -c "cp -r /source /backup/world && chown -R $(id -u):$(id -g) /backup/world"
    fi
    
    # Copy server configuration
    echo "Copying server configuration..."
    sudo docker cp "$container_name":/minecraft/server.properties "$temp_dir/" 2>/dev/null || echo "server.properties not found"
    sudo docker cp "$container_name":/minecraft/eula.txt "$temp_dir/" 2>/dev/null || echo "eula.txt not found"
    
    # Fix ownership of copied files
    sudo chown -R $(id -u):$(id -g) "$temp_dir"
    
    # Create backup zip
    echo "Creating backup archive..."
    cd "$temp_dir"
    zip -r "/home/$(whoami)/$backup_filename" . >/dev/null 2>&1
    
    # Cleanup with proper permissions
    cd /
    sudo rm -rf "$temp_dir"
    
    # Restart container if it was running
    if [ "$was_running" = true ]; then
        echo "Restarting container..."
        sudo docker start "$container_name"
    fi
    
    echo "Backup completed: /home/$(whoami)/$backup_filename"
}

# Main script
echo "Minecraft Server Backup Tool"
echo "============================="

# Check if any minecraft containers exist
containers=$(get_container_names)
if [ -z "$containers" ]; then
    echo "No Minecraft server containers found!"
    exit 1
fi

echo "Available Minecraft containers:"
list_minecraft_containers
echo ""

# Create menu items for whiptail
menu_items=()
while IFS= read -r container; do
    menu_items+=("$container" "")
done <<< "$containers"

# Add "All" option
menu_items+=("ALL" "Backup all containers")

# Show selection menu
SELECTED=$(whiptail --title "Backup Selection" \
    --menu "Choose container(s) to backup:" 20 60 10 \
    "${menu_items[@]}" \
    3>&1 1>&2 2>&3)

if [ -z "$SELECTED" ]; then
    echo "No selection made. Exiting."
    exit 0
fi

# Backup selected container(s)
if [ "$SELECTED" = "ALL" ]; then
    echo "Backing up all containers..."
    while IFS= read -r container; do
        backup_container "$container"
        echo ""
    done <<< "$containers"
else
    backup_container "$SELECTED"
fi

echo "Backup operation completed!"
EOF

chmod +x backup-minecraft.sh
echo "Backup script created: backup-minecraft.sh"
echo "Run './backup-minecraft.sh' to backup your Minecraft servers"
