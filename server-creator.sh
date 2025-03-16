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
    for dep in jq whiptail wget screen; do
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

    if ! command -v java &> /dev/null; then
        echo "Java is not installed. Installing..."
        case "$DISTRO" in
            "debian-based")
                sudo apt-get update
                sudo apt-get install -y openjdk-21-jdk
                ;;
            "fedora")
                sudo dnf install -y java-21-openjdk
                ;;
            "opensuse")
                sudo zypper install -y java-21-openjdk
                ;;
            "arch")
                sudo pacman -Syu --noconfirm jdk21-openjdk
                ;;
            *)
                echo "Unsupported distribution: $DISTRO"
                exit 1
                ;;
        esac
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

    # Get the server download URL from Mojang’s version details.
    SERVER_URL=$(curl -s "$MC_VERSION_URL" | jq -r '.downloads.server.url')

    whiptail --title "Downloading" --infobox "Downloading $MC_VERSION server.jar..." 8 50
    if wget -q -O server.jar "$SERVER_URL"; then
        echo "Download Succes"
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
    whiptail --title "Downloading" --infobox "Downloading Fabric server jar..." 8 60
    if wget -q -O server.jar "$DOWNLOAD_URL"; then
        echo "Download Succes"
    else
        whiptail --title "Error" --msgbox "Failed to download Fabric server jar!" 8 60
        return 1
    fi
}

install_dependencies

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

echo "#!/bin/bash
java -Xmx${mem}G -Xms${mem}G -jar server.jar nogui" > run.sh

echo "#!/bin/bash
cd $PWD
bash run.sh" > autostart.sh

if [ "$autostart" == "true" ]; then
    SERVICE_NAME="minecraft.service"
    SCREEN_SESSION="minecraft"
    RUN_SCRIPT="/usr/local/bin/autostart.sh"
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

    sudo cp autostart.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/autostart.sh

    echo "Creating systemd service at $SERVICE_FILE..."

sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
After=network.target

[Service]
Type=simple
ExecStart=$RUN_SCRIPT

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd, enable and start the service
    echo "Enabling and starting the service..."
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
    echo "Setup complete! Your script will now start at boot in a screen session named '$SCREEN_SESSION'."
    echo "To attach to it, use: screen -r $SCREEN_SESSION"
fi

# Terminate any existing screen session with the same name
if screen -list | grep -q "\.$SCREEN_SESSION"; then
    screen -S $SCREEN_SESSION -X quit &>/dev/null
fi

chmod +x run.sh

if [ "$start" == "true" ]; then
    sudo systemctl start minecraft
fi