"""
Core app views.
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import CreateAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

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


class LobbyJoinView(APIView):
    """Join an existing lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Check if already in lobby
        if LobbyMember.objects.filter(lobby=lobby, user=request.user).exists():
            return Response(
                {"detail": "You are already in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check if lobby is full
        if lobby.players.count() >= lobby.max_players:  # type: ignore[misc]
            return Response(
                {"detail": "Lobby is full."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check if lobby is still accepting players
        if lobby.status != Lobby.Status.WAITING:
            return Response(
                {"detail": "Lobby is not accepting players."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        LobbyMember.objects.create(lobby=lobby, user=request.user)

        # Broadcast player joined event
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                {"type": "player.joined", "username": request.user.username},
            )

        serializer = LobbySerializer(lobby)
        return Response(serializer.data, status=status.HTTP_200_OK)


class LobbyLeaveView(APIView):
    """Leave a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Check if user is in lobby
        try:
            membership = LobbyMember.objects.get(lobby=lobby, user=request.user)
        except LobbyMember.DoesNotExist:
            return Response(
                {"detail": "You are not in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # If host leaves, delete the lobby
        if lobby.host == request.user:
            lobby.delete()
            return Response({"detail": "Lobby deleted."}, status=status.HTTP_200_OK)

        # Otherwise just remove the player
        username = request.user.username
        membership.delete()

        # Broadcast player left event (only for non-host)
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}", {"type": "player.left", "username": username}
            )

        return Response({"detail": "Left lobby."}, status=status.HTTP_200_OK)


class LobbyReadyView(APIView):
    """Toggle ready state for a player in a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            membership = LobbyMember.objects.get(lobby=lobby, user=request.user)
        except LobbyMember.DoesNotExist:
            return Response(
                {"detail": "You are not in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        is_ready = request.data.get("is_ready", not membership.is_ready)
        membership.is_ready = is_ready
        membership.save()

        # Broadcast player ready state change
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                {
                    "type": "player.ready",
                    "username": request.user.username,
                    "is_ready": membership.is_ready,
                },
            )

        serializer = LobbySerializer(lobby)
        return Response(serializer.data, status=status.HTTP_200_OK)
