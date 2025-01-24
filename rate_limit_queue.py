import asyncio
import time
from logger import logger
from pterodactyl_api import pterodactyl_api


class RateLimitQueue:
    """Handles API requests with rate limits and prevents unnecessary updates."""

    def __init__(self, delay, max_requests, timeframe):
        """
        :param delay: Delay in seconds between each request
        :param max_requests: Maximum requests allowed per timeframe
        :param timeframe: Timeframe for max_requests enforcement (in seconds)
        """
        self.queue = asyncio.Queue()
        self.delay = delay
        self.max_requests = max_requests
        self.timeframe = timeframe
        self.request_timestamps = []
        self.running = False
        self.lock = asyncio.Lock()  # 🔒 Lock zur Vermeidung von Race Conditions
        self.processing_task = None
        self.last_rate_limit_wait = 0  # Speichert den letzten Discord-Rate-Limit-Wert

    def log_queue(self):
        """Logs the current queue size and upcoming tasks."""
        queue_size = self.queue.qsize()
        if queue_size > 0:
            logger.info(f"📋 Queue Status: {queue_size} tasks pending")
        else:
            logger.debug("✅ Queue is empty.")

    async def process_queue(self):
        """Processes the queue, ensuring stable request handling."""
        while not self.queue.empty():
            async with self.lock:
                try:
                    now = time.time()
                    self.request_timestamps = [t for t in self.request_timestamps if now - t < self.timeframe]

                    # 🛑 Falls ein Rate-Limit aktiv ist, warten wir
                    if self.last_rate_limit_wait > 0:
                        logger.warning(f"⏳ Waiting {self.last_rate_limit_wait:.2f} seconds due to rate limit...")
                        await asyncio.sleep(self.last_rate_limit_wait)
                        self.last_rate_limit_wait = 0  # Reset

                    if len(self.request_timestamps) >= self.max_requests:
                        sleep_time = self.timeframe - (now - self.request_timestamps[0])
                        logger.warning(f"⏳ Rate limit reached! Waiting {sleep_time:.2f} seconds...")
                        await asyncio.sleep(sleep_time)

                    batch_size = min(self.queue.qsize(), 5)
                    tasks = []

                    # 🆕 **Tasks auf ihre Gültigkeit prüfen, bevor sie ausgeführt werden**
                    for _ in range(batch_size):
                        task_info = await self.queue.get()
                        if await self.is_task_valid(task_info):
                            tasks.append(task_info)
                        else:
                            logger.info(f"🗑️ Removed outdated task for {task_info['server_name']} (status changed).")

                    # **Nur gültige Tasks ausführen**
                    for task_info in tasks:
                        try:
                            response = await task_info["task"]()
                            if response and hasattr(response, "retry_after"):
                                self.last_rate_limit_wait = response.retry_after
                                logger.warning(f"⏳ Discord rate limit detected: {response.retry_after} seconds")
                        except Exception as e:
                            logger.error(f"❌ Error executing task: {e}")

                        await asyncio.sleep(self.delay)

                    self.log_queue()

                except Exception as e:
                    logger.error(f"❌ Error processing queue: {e}")

            self.running = False
            self.processing_task = None

    async def add_task(self, coro, server_name=None, status=None):
        """Adds a task to the queue and starts processing if not already running."""
        task_info = {"task": coro, "server_name": server_name, "status": status}

        # 🛑 Falls genau dieser Task schon existiert, nicht erneut hinzufügen
        if any(t["server_name"] == server_name and t["status"] == status for t in self.queue._queue):
            logger.debug(f"🔄 Task already in queue for {server_name} (status: {status}), skipping duplicate.")
            return

        await self.queue.put(task_info)

        if not self.running:
            self.running = True
            self.processing_task = asyncio.create_task(self.process_queue())

    async def is_task_valid(self, task_info):
        """Checks if a queued task is still valid before execution."""
        server_name = task_info["server_name"]
        task_status = task_info["status"]

        if not server_name or not task_status:
            return True  # Falls der Task nicht mit einem Serverstatus verknüpft ist, führen wir ihn aus.

        current_status = pterodactyl_api.get_server_status(server_name)

        # **Falls der Serverstatus sich geändert hat, ignorieren wir den Task**
        if task_status != current_status:
            logger.warning(f"🗑️ Discarding outdated task for {server_name}: {task_status} → {current_status}")
            return False

        return True


