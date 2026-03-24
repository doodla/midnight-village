"""
Tests for structured logging configuration.

Validates that the base.py logging setup is correctly configured for production use.
Tests import the base settings directly since test settings intentionally disable
logging for performance.
"""

import logging
from io import StringIO
from typing import Any

import pytest

# Import base settings directly to test the production logging configuration
from config.settings import base as base_settings

pytestmark = pytest.mark.unit


def _get_logging_section(key: str) -> dict[str, Any]:
    """Get a section from LOGGING config as a dict."""
    section = base_settings.LOGGING.get(key, {})
    assert isinstance(section, dict)
    return section


class TestLoggingConfiguration:
    """Tests for the Django logging configuration in base.py."""

    def test_logging_config_exists(self) -> None:
        """Test that LOGGING configuration is defined in base settings."""
        assert hasattr(base_settings, "LOGGING")
        assert base_settings.LOGGING is not None

    def test_logging_has_required_formatters(self) -> None:
        """Test that required formatters are configured."""
        formatters = _get_logging_section("formatters")

        assert "verbose" in formatters
        assert "simple" in formatters

    def test_logging_has_console_handler(self) -> None:
        """Test that console handler is configured."""
        handlers = _get_logging_section("handlers")

        assert "console" in handlers
        assert handlers["console"]["class"] == "logging.StreamHandler"

    def test_logging_has_apps_logger(self) -> None:
        """Test that apps logger is configured for application code."""
        loggers = _get_logging_section("loggers")

        assert "apps" in loggers
        assert loggers["apps"]["level"] == "DEBUG"

    def test_logging_has_django_logger(self) -> None:
        """Test that django logger is configured."""
        loggers = _get_logging_section("loggers")

        assert "django" in loggers
        assert loggers["django"]["level"] == "INFO"

    def test_simple_formatter_includes_level_and_message(self) -> None:
        """Test that simple formatter includes log level and message."""
        formatters = _get_logging_section("formatters")
        simple_config = formatters.get("simple", {})
        assert isinstance(simple_config, dict)
        simple_format = simple_config.get("format", "")

        assert "levelname" in simple_format
        assert "message" in simple_format

    def test_verbose_formatter_includes_timestamp(self) -> None:
        """Test that verbose formatter includes timestamp."""
        formatters = _get_logging_section("formatters")
        verbose_config = formatters.get("verbose", {})
        assert isinstance(verbose_config, dict)
        verbose_format = verbose_config.get("format", "")

        assert "asctime" in verbose_format
        assert "levelname" in verbose_format
        assert "message" in verbose_format

    def test_apps_logger_produces_output(self) -> None:
        """Test that logging from apps namespace produces output."""
        # Create a string buffer to capture log output
        log_stream = StringIO()
        handler = logging.StreamHandler(log_stream)
        handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter("{levelname} {message}", style="{")
        handler.setFormatter(formatter)

        # Create a fresh logger to avoid test settings interference
        logger = logging.getLogger("apps.test")
        logger.setLevel(logging.DEBUG)
        logger.addHandler(handler)

        try:
            # Log a test message
            test_message = "Test log message from apps"
            logger.info(test_message)

            # Verify output
            log_output = log_stream.getvalue()
            assert "INFO" in log_output
            assert test_message in log_output
        finally:
            # Clean up
            logger.removeHandler(handler)

    def test_root_logger_level_is_info(self) -> None:
        """Test that root logger level is INFO."""
        root_config = _get_logging_section("root")

        assert root_config.get("level") == "INFO"

    def test_existing_loggers_not_disabled(self) -> None:
        """Test that existing loggers are not disabled in base settings."""
        assert base_settings.LOGGING.get("disable_existing_loggers") is False

    def test_console_handler_uses_simple_formatter(self) -> None:
        """Test that console handler uses the simple formatter."""
        handlers = _get_logging_section("handlers")
        console_handler = handlers.get("console", {})
        assert isinstance(console_handler, dict)

        assert console_handler.get("formatter") == "simple"
