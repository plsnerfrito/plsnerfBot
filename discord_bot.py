import discord
from discord.ext import commands
from logger import logger
from config import config  # Importing directly from config.py


class DiscordBot(commands.Bot):
    """Main class for the Discord bot."""

    def __init__(self):
        intents = discord.Intents.default()
        intents.messages = True
        intents.guilds = True
        super().__init__(command_prefix="!", intents=intents)

    async def on_ready(self):
        """Called when the bot has successfully started."""
        logger.info(f'✅ Logged in as {self.user} ({self.user.id})')
        for guild in self.guilds:
            logger.info(f"🔗 Connected to: {guild.name} (ID: {guild.id})")

        # Dynamically select the first available channel from `discord_channels`
        first_channel_id = next(iter(config.get("discord_channels", {}).values()), None)

        if first_channel_id:
            channel = self.get_channel(first_channel_id)
            if channel:
                await channel.send("🚀 Bot successfully connected and running!")
                logger.info("✅ Startup message successfully sent!")
            else:
                logger.error(f"❌ Error: Channel with ID {first_channel_id} not found!")
        else:
            logger.error("❌ Error: No valid channel ID found in the configuration!")

    async def send_discord_message(self, channel_id, message):
        """Sends a message to a Discord channel."""
        channel = self.get_channel(channel_id)
        if channel:
            await channel.send(message)
            logger.info(f"✅ Message sent: {message}")
        else:
            logger.error(f"❌ Could not find channel {channel_id}!")


bot = DiscordBot()