import asyncio
from discord_bot import bot
from pterodactyl_api import pterodactyl_api
from config import config
from language import lang  # Language support
from rate_limit_queue import RateLimitQueue
from logger import logger


class ServerMonitor:
    """Monitors Pterodactyl server status and updates Discord text and voice channels accordingly."""

    def __init__(self):
        self.last_status = {}
        self.last_channel_update = {}

        # 🎯 Nutzt die **beste** `RateLimitQueue`
        self.voice_rate_limiter = RateLimitQueue(delay=5, max_requests=2, timeframe=600)  # 2 alle 10 Min.
        self.text_rate_limiter = RateLimitQueue(delay=0.02, max_requests=50, timeframe=1)  # 50 pro Sekunde

    async def get_voice_channel_name(self, voice_channel_id):
        """Fetches the current voice channel name to avoid unnecessary updates."""
        channel = bot.get_channel(voice_channel_id)
        return channel.name if channel else None

    async def update_voice_channel(self, server_name, status):
        """Updates the voice channel name with the localized status, respecting rate limits."""

        config.reload_config()
        server_mapping = config.get("server_mappings", {}).get(server_name)
        if not server_mapping:
            logger.warning(f"⚠️ No mapping found for {server_name}, skipping...")
            return

        voice_channel_id = config.get_voice_channel(server_name)
        if not voice_channel_id:
            return  # Kein Voice-Kanal zugewiesen, also überspringen

        channel = bot.get_channel(voice_channel_id)
        if not channel:
            logger.error(f"❌ Voice channel {voice_channel_id} not found for {server_name}")
            return

        new_name = lang.get("voice_online" if status == "running" else "voice_offline", server=server_name)
        current_name = await self.get_voice_channel_name(voice_channel_id)

        if current_name == new_name:
            logger.info(f"⏳ Skipping voice channel update for {server_name} (already correct).")
            return

        async def edit_channel():
            try:
                response = await channel.edit(name=new_name)
                self.last_channel_update[server_name] = new_name
                logger.info(f"✅ Updated voice channel name to: {new_name}")
                return response
            except Exception as e:
                logger.error(f"❌ Failed to update voice channel name for {server_name}: {e}")

        await self.voice_rate_limiter.add_task(edit_channel)

    async def send_text_notification(self, server_name, status):
        """Sends a status update to the designated text channel, avoiding spam."""

        config.reload_config()
        text_channel_id = config.get_text_channel(server_name)
        if not text_channel_id:
            return  # Kein Text-Kanal zugewiesen, also überspringen

        # 🔄 Statusmeldungen für "starting" und "stopping"
        if status == "starting":
            message = lang.get("server_starting", server=server_name)
        elif status == "stopping":
            message = lang.get("server_stopping", server=server_name)
        elif status == "running":
            message = lang.get("server_online", server=server_name)
        else:
            message = lang.get("server_offline", server=server_name)

        async def send_message():
            try:
                response = await bot.send_discord_message(text_channel_id, message)
                logger.info(f"✅ Status update sent to {server_name}: {message}")
                return response
            except Exception as e:
                logger.error(f"❌ Failed to send status update for {server_name}: {e}")

        await self.text_rate_limiter.add_task(send_message)

    async def check_servers(self):
        """Periodically checks server status and updates Discord channels accordingly."""
        await bot.wait_until_ready()
        logger.info("📡 Server monitoring started...")

        while not bot.is_closed():
            config.reload_config()
            monitor_interval = config.get("monitor_interval", 60)

            servers = config.get("servers", {})
            server_mappings = config.get("server_mappings", {})

            for server_name, server_id in servers.items():
                status = pterodactyl_api.get_server_status(server_id)

                if server_name not in server_mappings:
                    logger.warning(
                        f"⚠️ Server {server_name} wurde aus der Config entfernt oder umbenannt. Ignoriere...")
                    continue

                if self.last_status.get(server_id) == status:
                    continue

                await self.send_text_notification(server_name, status)
                await self.update_voice_channel(server_name, status)

                self.last_status[server_id] = status

            await asyncio.sleep(monitor_interval)

    async def validate_discord_status(self):
        """Regularly checks if the displayed Discord status matches the actual API status."""
        await bot.wait_until_ready()

        while not bot.is_closed():
            config.reload_config()
            logger.info("🔄 Running periodic status validation...")

            servers = config.get("servers", {})

            for server_name, server_id in servers.items():
                actual_status = pterodactyl_api.get_server_status(server_id)
                displayed_status = self.last_status.get(server_id)

                # Falls sich der Status geändert hat oder ein Mismatch existiert
                if actual_status != displayed_status:
                    logger.warning(
                        f"⚠️ Status mismatch detected for {server_name}: API says '{actual_status}', Discord shows '{displayed_status}'")

                    # Erneut Text- und Voice-Updates anstoßen
                    await self.send_text_notification(server_name, actual_status)
                    await self.update_voice_channel(server_name, actual_status)

                    # Aktualisiere gespeicherten Status
                    self.last_status[server_id] = actual_status

            # ⏳ Intervall für die Statusvalidierung (einstellbar in `config.json`)
            validation_interval = config.get("status_validation_interval", 300)  # Default: alle 5 Minuten
            await asyncio.sleep(validation_interval)


server_monitor = ServerMonitor()
