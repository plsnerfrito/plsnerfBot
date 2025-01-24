#!/bin/bash
# plsnerfBot Modular Installer - Interactive Setup

INSTALL_DIR="/opt/plsnerfbot"
CONFIG_FILE="$INSTALL_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/plsnerfbot.service"

# 🛑 Function to uninstall plsnerfBot
function uninstall_plsnerfbot() {
    echo "🚀 Uninstalling plsnerfBot..."
    sudo systemctl stop plsnerfbot 2>/dev/null
    sudo systemctl disable plsnerfbot 2>/dev/null
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo rm -rf "$INSTALL_DIR"
    echo "✅ plsnerfBot successfully uninstalled."
}

# 🟢 Function to install dependencies
function install_dependencies() {
    echo "📦 Installing dependencies..."
    sudo apt update && sudo apt install -y python3 python3-venv curl git
}

# 🔄 Function to install plsnerfBot
function install_plsnerfbot() {
    echo "🚀 Installing plsnerfBot..."

    # 🔄 Clean and create installation directory
    if [ -d "$INSTALL_DIR" ]; then
        sudo rm -rf "$INSTALL_DIR"
    fi
    sudo mkdir -p "$INSTALL_DIR"

    # 📥 Clone the latest code from GitHub
    echo "📥 Cloning the latest code from GitHub..."
    cd /tmp || exit
    sudo git clone https://github.com/plsnerfrito/plsnerfBot.git "$INSTALL_DIR"

    cd "$INSTALL_DIR" || exit
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
}

# ⚙️ Function to configure plsnerfBot
function configure_plsnerfbot() {
    echo "🔧 Configuring plsnerfBot..."

    read -p "🌐 Pterodactyl Panel URL: " PTERO_URL
    read -p "🔑 Pterodactyl API Key: " PTERO_API
    read -p "🤖 Discord Bot Token: " DISCORD_BOT
    read -p "⏱️ Monitoring Interval (seconds, default 60): " MONITOR_INTERVAL
    MONITOR_INTERVAL=${MONITOR_INTERVAL:-60}

    # 🌍 Select bot language
    echo "🌍 Select the bot language:"
    echo "1) English (Default)"
    echo "2) German"
    read -p "Enter choice (1/2): " LANG_CHOICE

    case "$LANG_CHOICE" in
        2) BOT_LANGUAGE="de" ;;
        *) BOT_LANGUAGE="en" ;;
    esac

    # Discord channels
    declare -A DISCORD_CHANNELS
    declare -A SERVERS
    declare -A SERVER_TO_TEXT_CHANNEL
    declare -A SERVER_TO_VOICE_CHANNEL

    echo "💬 Add Discord channels (Press ENTER when done)"
    while true; do
        read -p "➕ Channel Name (e.g., 'lobby-status'): " CHANNEL_NAME
        if [ -z "$CHANNEL_NAME" ]; then break; fi
        read -p "📌 Discord Channel ID for '$CHANNEL_NAME': " CHANNEL_ID
        DISCORD_CHANNELS[$CHANNEL_NAME]=$CHANNEL_ID
    done

    echo "🖥️ Add Pterodactyl servers (Press ENTER when done)"
    while true; do
        read -p "➕ Server Name (e.g., 'Lobby'): " SERVER_NAME
        if [ -z "$SERVER_NAME" ]; then break; fi
        read -p "📌 Server UUID from Pterodactyl for '$SERVER_NAME': " SERVER_ID
        SERVERS[$SERVER_NAME]=$SERVER_ID
    done

    echo "📡 Assign servers to Discord text and voice channels:"
    for SERVER in "${!SERVERS[@]}"; do
        echo "💬 Select a text channel for '$SERVER' (or press ENTER to skip):"
        select CH in "${!DISCORD_CHANNELS[@]}"; do
            if [ -n "$CH" ]; then
                SERVER_TO_TEXT_CHANNEL[$SERVER]=$CH
                break
            fi
        done

        echo "🔊 Select a voice channel for '$SERVER' (or press ENTER to skip):"
        select CH in "${!DISCORD_CHANNELS[@]}"; do
            if [ -n "$CH" ]; then
                SERVER_TO_VOICE_CHANNEL[$SERVER]=$CH
                break
            fi
        done
    done

    # 📝 Save config.json
    echo "📝 Saving config.json..."
    {
        echo "{"
        echo "  \"language\": \"$BOT_LANGUAGE\","
        echo "  \"pterodactyl_panel_url\": \"$PTERO_URL\","
        echo "  \"pterodactyl_api_key\": \"$PTERO_API\","
        echo "  \"discord_bot_token\": \"$DISCORD_BOT\","
        echo "  \"monitor_interval\": $MONITOR_INTERVAL,"
        echo "  \"discord_channels\": {"

        COUNT=0
        TOTAL=${#DISCORD_CHANNELS[@]}
        for CH in "${!DISCORD_CHANNELS[@]}"; do
            COUNT=$((COUNT + 1))
            echo -n "    \"$CH\": ${DISCORD_CHANNELS[$CH]}"
            if [ "$COUNT" -lt "$TOTAL" ]; then echo ","; else echo ""; fi
        done

        echo "  },"
        echo "  \"servers\": {"

        COUNT=0
        TOTAL=${#SERVERS[@]}
        for SERVER in "${!SERVERS[@]}"; do
            COUNT=$((COUNT + 1))
            echo -n "    \"$SERVER\": \"${SERVERS[$SERVER]}\""
            if [ "$COUNT" -lt "$TOTAL" ]; then echo ","; else echo ""; fi
        done

        echo "  },"
        echo "  \"server_mappings\": {"

        COUNT=0
        TOTAL=${#SERVERS[@]}
        for SERVER in "${!SERVERS[@]}"; do
            COUNT=$((COUNT + 1))
            echo -n "    \"$SERVER\": {"
            echo -n "      \"text_channel\": \"${SERVER_TO_TEXT_CHANNEL[$SERVER]}\","
            echo -n "      \"voice_channel\": \"${SERVER_TO_VOICE_CHANNEL[$SERVER]}\""
            echo -n "    }"
            if [ "$COUNT" -lt "$TOTAL" ]; then echo ","; else echo ""; fi
        done

        echo "  }"
        echo "}"
    } > "$CONFIG_FILE"

    echo "✅ Configuration saved!"
}

# 🛠 Function to set up the systemd service
function setup_service() {
    echo "🔧 Creating systemd service for plsnerfBot..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=plsnerfBot Status Monitor
After=network.target

[Service]
ExecStart=/opt/plsnerfbot/venv/bin/python3 /opt/plsnerfbot/bot.py
Restart=always
User=root
WorkingDirectory=/opt/plsnerfbot

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable plsnerfbot
    sudo systemctl start plsnerfbot

    echo "✅ plsnerfBot is installed and running as a system service!"
}

# 🏁 Main menu
echo "Welcome to the plsnerfBot setup!"
echo "Choose an option:"
echo "1) Install plsnerfBot"
echo "2) Uninstall plsnerfBot"
echo "3) Reinstall plsnerfBot"
read -p "Enter your choice (1/2/3): " CHOICE

case "$CHOICE" in
    1)
        install_dependencies
        install_plsnerfbot
        configure_plsnerfbot
        setup_service
        ;;
    2)
        uninstall_plsnerfbot
        ;;
    3)
        uninstall_plsnerfbot
        install_dependencies
        install_plsnerfbot
        configure_plsnerfbot
        setup_service
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac
