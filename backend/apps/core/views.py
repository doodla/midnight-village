"""
Core app views.
"""

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import CreateAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from .models import Lobby, LobbyMember
from .serializers import LobbyCreateSerializer, LobbySerializer


@api_view(["GET"])
@permission_classes([AllowAny])
def health_check(request: Request) -> Response:
    """
    Health check endpoint for monitoring and load balancer probes.

    Returns:
        Response: JSON response with status "ok"
    """
    return Response({"status": "ok"}, status=status.HTTP_200_OK)


class LobbyCreateView(CreateAPIView):
    """Create a new lobby."""

    serializer_class = LobbyCreateSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        lobby = serializer.save(host=self.request.user)
        # Add host as first player
        LobbyMember.objects.create(lobby=lobby, user=self.request.user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)

        # Return full lobby data
        lobby = serializer.instance
        output_serializer = LobbySerializer(lobby)
        return Response(output_serializer.data, status=status.HTTP_201_CREATED)


class LobbyDetailView(RetrieveAPIView):
    """Retrieve a lobby by code."""

    serializer_class = LobbySerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "code"
    queryset = Lobby.objects.all()
