import time
import requests
from logger import logger
from config import config


class PterodactylAPI:
    """Handles Pterodactyl API requests while caching server status to prevent unnecessary API calls."""

    def __init__(self):
        self.api_url = config.get("pterodactyl_panel_url")
        self.api_key = config.get("pterodactyl_api_key")
        self.cache = {}  # Stores last known status
        self.cache_time = {}

    def get_server_status(self, server_id):
        """Fetches the server status from Pterodactyl API while caching the response."""
        current_time = time.time()
        cache_expiry = config.get("monitor_interval", 60)
        if server_id in self.cache and (current_time - self.cache_time.get(server_id, 0)) < cache_expiry:
            return self.cache[server_id]  # Use cached result if less than 60s old

        headers = {"Authorization": f"Bearer {self.api_key}", "Accept": "application/json"}
        response = requests.get(f"{self.api_url}/api/client/servers/{server_id}/resources", headers=headers)

        if response.status_code == 200:
            status = response.json()["attributes"]["current_state"]
            self.cache[server_id] = status
            self.cache_time[server_id] = current_time
            return status

        logger.error(f"⚠️ Error fetching server status for {server_id}: {response.text}")
        return "unknown"

pterodactyl_api = PterodactylAPI()