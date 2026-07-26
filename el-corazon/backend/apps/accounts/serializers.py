"""Contrats d'entrée et de sortie de l'identité — ADR-009.

Les sérialiseurs valident la **forme**. Les décisions métier — le mot de passe
actuel est-il correct, faut-il révoquer les sessions — appartiennent au service.
"""

from __future__ import annotations

from typing import Any

from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from apps.accounts.models import Device, DevicePlatform, User

__all__ = [
    "ChangePasswordSerializer",
    "DeviceSerializer",
    "LoginSerializer",
    "RegisterSerializer",
    "TokenPairSerializer",
    "UserSerializer",
]


class UserSerializer(serializers.ModelSerializer):
    """Représentation publique d'un compte.

    Forme **unique** : `/auth/register`, `/auth/login` et `/auth/me` renvoient
    exactement les mêmes clés. L'implémentation précédente en avait deux —
    8 clés à l'inscription contre 15 sur `/me` — deux formes divergentes du
    même objet, que chaque client devait apprendre séparément.
    """

    permissions = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "phone",
            "full_name",
            "user_type",
            "avatar",
            "is_active",
            "email_verified_at",
            "phone_verified_at",
            "last_seen_at",
            "permissions",
            "created_at",
            "updated_at",
        ]
        # `created_at` et `updated_at` ne sont jamais omis : les clients Dart
        # actuels appellent `DateTime.parse` sans garde nulle, et un champ
        # absent ne dégrade pas l'affichage — il fait planter la connexion.
        read_only_fields = fields

    def get_permissions(self, obj: User) -> list[str]:
        """Vide pour un client ou un livreur — seul le personnel en détient."""
        return sorted(obj.permission_codes())


class TokenPairSerializer(serializers.Serializer):
    access = serializers.CharField(read_only=True)
    refresh = serializers.CharField(read_only=True)
    user = UserSerializer(read_only=True)


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8, trim_whitespace=False)
    full_name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=16, required=False, allow_blank=True)

    def validate_email(self, value: str) -> str:
        normalized = value.strip().lower()
        if User.objects.filter(email__iexact=normalized).exists():
            raise serializers.ValidationError("Un compte existe déjà avec cette adresse.")
        return normalized

    def validate_phone(self, value: str) -> str:
        if value and User.objects.filter(phone=value).exists():
            raise serializers.ValidationError("Un compte existe déjà avec ce numéro.")
        return value

    def validate_password(self, value: str) -> str:
        validate_password(value)
        return value


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_email(self, value: str) -> str:
        return value.strip().lower()


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password = serializers.CharField(write_only=True, min_length=8, trim_whitespace=False)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if attrs["current_password"] == attrs["new_password"]:
            raise serializers.ValidationError(
                {"new_password": "Le nouveau mot de passe doit être différent de l'actuel."}
            )
        return attrs


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class DeviceSerializer(serializers.ModelSerializer):
    platform = serializers.ChoiceField(choices=DevicePlatform.choices)

    class Meta:
        model = Device
        fields = ["id", "token", "platform", "last_used_at", "created_at"]
        read_only_fields = ["id", "last_used_at", "created_at"]
