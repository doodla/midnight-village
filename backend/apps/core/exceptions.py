"""
Core app exception handling utilities.
"""

from typing import Any

from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler


def custom_exception_handler(
    exc: Exception, context: dict[str, Any]
) -> Response | None:
    """
    Custom exception handler for DRF.

    Wraps the default handler to ensure consistent error response format.

    Args:
        exc: The exception instance
        context: The context dictionary with view, request, etc.

    Returns:
        Response: JSON error response or None to propagate
    """
    response = drf_exception_handler(exc, context)

    if response is not None:
        # Handle both dict and list response data formats
        detail = response.data
        if isinstance(response.data, dict):
            detail = response.data.get("detail", response.data)

        response.data = {
            "error": {
                "status_code": response.status_code,
                "detail": detail,
            }
        }

    return response
