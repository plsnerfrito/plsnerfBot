import json
from logger import logger

CONFIG_FILE = "config.json"

class Config:
    """Loads and manages the bot configuration from config.json dynamically."""

    def __init__(self):
        self._config = self.load_config()
        self.language = self.get("language", "en")  # Default: English

    def load_config(self):
        """Loads the config file and handles errors."""
        try:
            with open(CONFIG_FILE, "r") as file:
                return json.load(file)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            logger.error(f"❌ Error loading config.json: {e}")
            return {}

    def reload_config(self):
        """🔄 Reloads the config file dynamically."""
        self._config = self.load_config()
        #logger.info("🔄 Config reloaded successfully!")

    def get(self, key, default=None):
        """Retrieves a value from the config dictionary."""
        return self._config.get(key, default)

    def get_server_mappings(self):
        """Returns the server-to-channel mappings."""
        return self.get("server_mappings", {})

    def get_servers(self):
        """Returns the list of servers and their IDs."""
        return self.get("servers", {})

    def get_text_channel(self, server_name):
        """Returns the assigned text channel ID for a given server."""
        mappings = self.get_server_mappings()
        if server_name in mappings and "text_channel" in mappings[server_name]:
            channel_name = mappings[server_name]["text_channel"]
            channel_id = self.get("discord_channels", {}).get(channel_name)
            if channel_id:
                return channel_id
            logger.warning(f"⚠️ No valid text channel ID found for server: {server_name}")
        return None

    def get_voice_channel(self, server_name):
        """Returns the assigned voice channel ID for a given server."""
        mappings = self.get_server_mappings()
        if server_name in mappings and "voice_channel" in mappings[server_name]:
            channel_name = mappings[server_name]["voice_channel"]
            channel_id = self.get("discord_channels", {}).get(channel_name)
            if channel_id:
                return channel_id
            logger.warning(f"⚠️ No valid voice channel ID found for server: {server_name}")
        return None

# Create a global instance
config = Config()