import asyncio
from logger import logger
from discord_bot import bot
from server_monitor import server_monitor
from config import config
from language import lang

async def on_ready_task():
    """Sends the startup message in the selected language."""
    logger.info("📢 Sending startup message...")

    first_channel_id = next(iter(config.get("discord_channels", {}).values()), None)
    if first_channel_id:
        channel = bot.get_channel(first_channel_id)
        if channel:
            await channel.send(lang.get("bot_started"))

    # 📡 Start server monitoring
    logger.info("📡 Starting server monitoring...")
    asyncio.create_task(server_monitor.check_servers())

    # 🆕 Starte regelmäßige Status-Validierung
    validation_interval = config.get("status_validation_interval", 300)  # Standard: 5 Minuten
    logger.info(f"🔄 Starting periodic status validation (every {validation_interval} sec)...")
    asyncio.create_task(server_monitor.validate_discord_status())

@bot.event
async def on_ready():
    """Called when the bot is ready."""
    logger.info("✅ Bot is online!")
    await on_ready_task()

async def main():
    """Starts the Discord bot."""
    async with bot:
        await bot.start(config.get("discord_bot_token"))

if __name__ == "__main__":
    asyncio.run(main())
