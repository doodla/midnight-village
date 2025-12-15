"""
Contract tests for error response format.

Validates that all DRF-handled API error responses follow the structured format:
{
    "error": {
        "status_code": <int>,
        "detail": <string or dict>
    }
}

Note: Only tests DRF-handled errors (405, etc.). Django-level 404s for non-existent
URLs bypass DRF and return HTML. DRF 404s (e.g., object not found in a ViewSet)
will be tested when such endpoints exist.
"""

import pytest
from rest_framework import status


@pytest.mark.django_db
class TestErrorResponseFormat:
    """Contract tests verifying error response structure for DRF errors."""

    def test_405_error_has_correct_structure(self, api_client):
        """Test that 405 errors return the structured error format."""
        response = api_client.post("/api/health/")

        assert response.status_code == status.HTTP_405_METHOD_NOT_ALLOWED
        data = response.json()

        assert "error" in data
        assert "status_code" in data["error"]
        assert "detail" in data["error"]
        assert data["error"]["status_code"] == 405

    def test_405_error_detail_is_string_or_dict(self, api_client):
        """Test that error detail can be a string or dict."""
        response = api_client.post("/api/health/")
        data = response.json()

        detail = data["error"]["detail"]
        assert isinstance(detail, str | dict)

    def test_error_response_content_type_is_json(self, api_client):
        """Test that DRF error responses have JSON content type."""
        response = api_client.post("/api/health/")

        assert response["Content-Type"] == "application/json"

    def test_error_status_code_matches_http_status(self, api_client):
        """Test that error.status_code matches HTTP response status."""
        response = api_client.post("/api/health/")

        data = response.json()
        assert data["error"]["status_code"] == response.status_code

    def test_put_method_not_allowed_error_format(self, api_client):
        """Test that PUT on health endpoint returns structured error."""
        response = api_client.put("/api/health/")

        assert response.status_code == status.HTTP_405_METHOD_NOT_ALLOWED
        data = response.json()

        assert "error" in data
        assert data["error"]["status_code"] == 405

    def test_delete_method_not_allowed_error_format(self, api_client):
        """Test that DELETE on health endpoint returns structured error."""
        response = api_client.delete("/api/health/")

        assert response.status_code == status.HTTP_405_METHOD_NOT_ALLOWED
        data = response.json()

        assert "error" in data
        assert data["error"]["status_code"] == 405

    def test_patch_method_not_allowed_error_format(self, api_client):
        """Test that PATCH on health endpoint returns structured error."""
        response = api_client.patch("/api/health/")

        assert response.status_code == status.HTTP_405_METHOD_NOT_ALLOWED
        data = response.json()

        assert "error" in data
        assert data["error"]["status_code"] == 405
