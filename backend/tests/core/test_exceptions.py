"""
Tests for core exception handling utilities.

This module contains both isolated unit tests (using mocks) and integration tests
(using real HTTP requests) for the custom exception handler.
"""

from unittest.mock import MagicMock, patch

from django.urls import reverse

import pytest
from rest_framework.response import Response

from apps.core.exceptions import custom_exception_handler


class TestCustomExceptionHandlerUnit:
    """Unit tests for custom_exception_handler function."""

    def test_returns_none_when_drf_handler_returns_none(self):
        """Handler should return None when DRF handler returns None."""
        exc = Exception("Test exception")
        context = {"view": MagicMock()}

        with patch("apps.core.exceptions.drf_exception_handler", return_value=None):
            result = custom_exception_handler(exc, context)

        assert result is None

    def test_wraps_dict_response_with_detail_key(self):
        """Handler should extract 'detail' from dict response data."""
        exc = Exception("Test exception")
        context = {"view": MagicMock()}

        mock_response = MagicMock(spec=Response)
        mock_response.data = {"detail": "Not found"}
        mock_response.status_code = 404

        with patch(
            "apps.core.exceptions.drf_exception_handler",
            return_value=mock_response,
        ):
            result = custom_exception_handler(exc, context)

        assert result is mock_response
        assert result.data == {
            "error": {
                "status_code": 404,
                "detail": "Not found",
            }
        }

    def test_wraps_dict_response_without_detail_key(self):
        """Handler should use entire dict when 'detail' key is missing."""
        exc = Exception("Test exception")
        context = {"view": MagicMock()}

        mock_response = MagicMock(spec=Response)
        mock_response.data = {"field": ["Error message"]}
        mock_response.status_code = 400

        with patch(
            "apps.core.exceptions.drf_exception_handler",
            return_value=mock_response,
        ):
            result = custom_exception_handler(exc, context)

        assert result is not None
        assert result.data == {
            "error": {
                "status_code": 400,
                "detail": {"field": ["Error message"]},
            }
        }

    def test_wraps_list_response_data(self):
        """Handler should preserve list response data as detail."""
        exc = Exception("Test exception")
        context = {"view": MagicMock()}

        mock_response = MagicMock(spec=Response)
        mock_response.data = ["Error 1", "Error 2"]
        mock_response.status_code = 400

        with patch(
            "apps.core.exceptions.drf_exception_handler",
            return_value=mock_response,
        ):
            result = custom_exception_handler(exc, context)

        assert result is not None
        assert result.data == {
            "error": {
                "status_code": 400,
                "detail": ["Error 1", "Error 2"],
            }
        }

    def test_preserves_status_code(self):
        """Handler should preserve the original status code."""
        exc = Exception("Test exception")
        context = {"view": MagicMock()}

        for status_code in [400, 401, 403, 404, 500]:
            mock_response = MagicMock(spec=Response)
            mock_response.data = {"detail": "Error"}
            mock_response.status_code = status_code

            with patch(
                "apps.core.exceptions.drf_exception_handler",
                return_value=mock_response,
            ):
                result = custom_exception_handler(exc, context)

            # Result is the same object as mock_response (modified in place)
            assert result is mock_response
            response_data: dict = mock_response.data
            assert response_data["error"]["status_code"] == status_code


@pytest.mark.django_db
class TestCustomExceptionHandlerIntegration:
    """Integration tests for the custom DRF exception handler."""

    def test_405_error_response_format(self, api_client):
        """Test that 405 errors return consistent error format."""
        url = reverse("core:health-check")
        response = api_client.post(url)

        assert response.status_code == 405
        data = response.json()
        assert "error" in data
        assert "status_code" in data["error"]
        assert "detail" in data["error"]
        assert data["error"]["status_code"] == 405

    def test_error_response_contains_detail_message(self, api_client):
        """Test that error responses contain meaningful detail messages."""
        url = reverse("core:health-check")
        response = api_client.post(url)

        data = response.json()
        # 405 should have a detail about method not allowed
        assert "Method" in str(data["error"]["detail"]) or data["error"]["detail"]
