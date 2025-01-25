#!/bin/bash
# plsnerfBot Modular Installer - Supports Pterodactyl & Systemd

INSTALL_DIR="/opt/plsnerfbot"
CONFIG_FILE="$INSTALL_DIR/config.json"
BACKUP_FILE="$INSTALL_DIR/config_backup.json"
SERVICE_FILE="/etc/systemd/system/plsnerfbot.service"
PTERO_MODE="false"

# 🟢 Function to detect Pterodactyl environment
function detect_pterodactyl() {
    declare -g PTERO_MODE

    if [[ -d "/home/container" ]] || [[ "$HOME" == "/home/container" ]] || env | grep -qi 'PTERO'; then
        echo "✔ Pterodactyl environment detected."
        PTERO_MODE="true"
    else
        echo "✔ No Pterodactyl detected."
        PTERO_MODE="false"
    fi
}

# 🛑 Function to uninstall plsnerfBot
function uninstall_plsnerfbot() {
    echo "🚀 Uninstalling plsnerfBot..."
    sudo systemctl stop plsnerfbot 2>/dev/null || true
    sudo systemctl disable plsnerfbot 2>/dev/null || true
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo rm -rf "$INSTALL_DIR"
    echo "✅ plsnerfBot successfully uninstalled."
}

# 🟢 Function to install dependencies
function install_dependencies() {
    echo "📦 Installing dependencies..."
    if [[ "$PTERO_MODE" == "true" ]]; then
        apt-get update && apt-get install -y python3 python3-venv curl git
    else
        sudo apt-get update && sudo apt-get install -y python3 python3-venv curl git
    fi
}

# 🔄 Function to install plsnerfBot
function install_plsnerfbot() {
    echo "🚀 Installing plsnerfBot..."

    # 🔄 Clean and create installation directory
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    mkdir -p "$INSTALL_DIR"

    # 📥 Clone the latest code from GitHub
    echo "📥 Cloning the latest code from GitHub..."
    cd /tmp || exit
    git clone https://github.com/plsnerfrito/plsnerfBot.git "$INSTALL_DIR"

    cd "$INSTALL_DIR" || exit
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
}

# 🔄 Update plsnerfBot
function update_plsnerfbot() {
    echo "🔄 Updating plsnerfBot..."
    cd "$INSTALL_DIR" || exit
    git pull
    echo "✅ Update complete!"
}

# ⚙️ Function to configure plsnerfBot
function configure_plsnerfbot() {
    echo "🔧 Configuring plsnerfBot..."

    # Prüfe, ob wir in einem Pterodactyl-Container sind
    if [ "$PTERO_MODE" = true ]; then
        echo "✔ Using environment variables for configuration."

        PTERO_URL=${PTERO_URL:-"http://localhost"}
        PTERO_API=${PTERO_API}
        DISCORD_BOT=${DISCORD_BOT}
        MONITOR_INTERVAL=${MONITOR_INTERVAL:-60}
        BOT_LANGUAGE=${BOT_LANGUAGE:-"en"}

        if [ -z "$PTERO_API" ] || [ -z "$DISCORD_BOT" ]; then
            echo "❌ ERROR: PTERO_API and DISCORD_BOT must be set in Pterodactyl!"
            exit 1
        fi
    else
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
    fi

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

# 🏁 Main menu (Pterodactyl)
detect_pterodactyl

if [[ "$PTERO_MODE" == "true" ]]; then
    echo "🚀 Running automatic setup for Pterodactyl..."
    install_dependencies
    install_plsnerfbot
    configure_plsnerfbot
    echo "✅ plsnerfBot installed successfully in Pterodactyl! It will start when the container starts."
    exit 0
fi

# 🏁 Main menu (no Pterodactyl)
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