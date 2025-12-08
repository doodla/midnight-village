"""
Integration tests for health check endpoint.
"""

import pytest
from django.urls import reverse


@pytest.mark.integration
@pytest.mark.django_db
class TestHealthCheckEndpoint:
    """Tests for the /api/health/ endpoint."""

    def test_health_check_returns_ok(self, api_client):
        """Test that health check endpoint returns status ok."""
        url = reverse("core:health-check")
        response = api_client.get(url)

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    def test_health_check_allows_any_permission(self, api_client):
        """Test that health check is accessible without authentication."""
        url = reverse("core:health-check")
        response = api_client.get(url)

        assert response.status_code == 200

    def test_health_check_returns_json(self, api_client):
        """Test that health check returns JSON content type."""
        url = reverse("core:health-check")
        response = api_client.get(url)

        assert response["Content-Type"] == "application/json"

    def test_health_check_rejects_post(self, api_client):
        """Test that health check rejects POST requests with 405."""
        url = reverse("core:health-check")
        response = api_client.post(url)

        assert response.status_code == 405

    def test_health_check_rejects_put(self, api_client):
        """Test that health check rejects PUT requests with 405."""
        url = reverse("core:health-check")
        response = api_client.put(url)

        assert response.status_code == 405

    def test_health_check_rejects_delete(self, api_client):
        """Test that health check rejects DELETE requests with 405."""
        url = reverse("core:health-check")
        response = api_client.delete(url)

        assert response.status_code == 405

    def test_health_check_rejects_patch(self, api_client):
        """Test that health check rejects PATCH requests with 405."""
        url = reverse("core:health-check")
        response = api_client.patch(url)

        assert response.status_code == 405
