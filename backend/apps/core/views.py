"""
Core app views.
"""

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response


@api_view(["GET"])
@permission_classes([AllowAny])
def health_check(request: Request) -> Response:
    """
    Health check endpoint for monitoring and load balancer probes.

    Returns:
        Response: JSON response with status "ok"
    """
    return Response({"status": "ok"}, status=status.HTTP_200_OK)
