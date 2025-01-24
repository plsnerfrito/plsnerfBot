import json
import os
from logger import logger
from config import config


class LanguageManager:
    """Loads and manages language files based on the configuration."""

    def __init__(self):
        self.language = config.get("language", "en")
        self.translations = self.load_language_file()

    def load_language_file(self):
        """Loads the language file based on the configuration."""
        lang_file = f"locales/{self.language}.json"
        if not os.path.exists(lang_file):
            logger.warning(f"⚠️ Language file {lang_file} not found! Falling back to English.")
            lang_file = "locales/en.json"

        try:
            with open(lang_file, "r", encoding="utf-8") as file:
                return json.load(file)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            logger.error(f"❌ Error loading language file: {e}")
            return {}

    def get(self, key, **kwargs):
        """Returns a translated string, supporting placeholders."""
        text = self.translations.get(key, key)  # Fallback to key if not found
        return text.format(**kwargs) if kwargs else text

# Create a global instance
lang = LanguageManager()
