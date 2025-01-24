import logging
import sys

def setup_logger():
    """Configures logging to be used globally, ensuring journalctl compatibility."""
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    formatter = logging.Formatter("%(asctime)s [%(levelname)s]: %(message)s")

    # Console handler for systemd logs
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

setup_logger()

# Export the global logger instance
logger = logging.getLogger(__name__)  # Holt den Logger einmal für das ganze Projekt
