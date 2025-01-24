# plsnerfBot 🦖  
**A modular status bot for Pterodactyl that automatically sends server status updates to Discord.**

---

## 🚀 Features  
✅ Real-time monitoring of Pterodactyl servers  
✅ Automatic status updates sent to Discord channels  
✅ Easy installation via `bash <(curl -s https://raw.githubusercontent.com/plsnerfrito/plsnerfBot/main/installer.sh)`  
✅ Modular design

---

## 📌 Installation  
1. **Run the installation script:**  
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/plsnerfrito/plsnerfBot/main/installer.sh)
   ```
2. **Follow the interactive setup:**  
   - Enter your Pterodactyl panel URL.  
   - Provide your Pterodactyl API key.  
   - Input your Discord bot token.  
   - Configure monitoring intervals and map servers to Discord channels.  

---

## 🛠️ Configuration  
The `config.json` file is automatically generated during installation. Below is an explanation of its parameters:

- **`pterodactyl_panel_url`**:  
  URL of your Pterodactyl panel. Example: `"https://panel.example.com"`

- **`pterodactyl_api_key`**:  
  API key for authenticating with the Pterodactyl API. You can generate this key in your Pterodactyl user settings.

- **`discord_bot_token`**:  
  Token for your Discord bot, generated in the Discord developer portal.

- **`monitor_interval`**:  
  Time in seconds between status checks. Default is `60`.

- **`discord_channels`**:  
  Mapping of Discord channel names to their channel IDs. Example: `"Lobby-Status": 123456789012345678`

- **`servers`**:  
  Mapping of server names to their UUIDs from Pterodactyl. Example: `"Lobby": "abc123xyz"`

- **`server_channel_map`**:  
  Maps servers to their designated Discord channels. Example: `"Lobby": "Lobby-Status"`

- **`language`**:  
  Language for bot messages. Supported values: `"en"` for English, `"de"` for German.

---

## 🎯 How It Works  
1. `plsnerfBot` fetches **server status from Pterodactyl's API**.  
2. If a server **goes online or offline**, a message is sent to the **assigned Discord channel**.  
3. The bot runs **as a systemd service**, ensuring automatic startup after reboots.

Example Discord messages:  
✅ `Lobby is now online!`  
⚠️ `Vanilla is offline! Please check.`  

---

## 🛠️ Systemd Service  
After installation, `plsnerfBot` runs as a **systemd service**.  

- **Start or restart the bot:**  
  ```bash
  sudo systemctl restart plsnerfbot
  ```

- **Check logs:**  
  ```bash
  journalctl -u plsnerfbot --no-pager --lines=50
  ```

---

## 📢 Contributing  
We welcome contributions! Submit an **issue** or **pull request** to help improve `plsnerfBot`.

### ✅ Planned Features  
- Your input needet!

---

## 📜 License  
This project is licensed under the **Apache 2.0 License**.  

Start monitoring your servers with `plsnerfBot` today! 🚀  
