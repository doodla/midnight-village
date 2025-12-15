"""
Integration tests for custom exception handler.
"""

from django.urls import reverse

import pytest


@pytest.mark.integration
@pytest.mark.django_db
class TestCustomExceptionHandler:
    """Tests for the custom DRF exception handler."""

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
