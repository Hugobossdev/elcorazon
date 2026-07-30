"""Contrats d'entrée et de sortie de l'identité — ADR-009.

Les sérialiseurs valident la **forme**. Les décisions métier — le mot de passe
actuel est-il correct, faut-il révoquer les sessions — appartiennent au service.
"""

from __future__ import annotations

from typing import Any

from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from apps.accounts.models import Device, DevicePlatform, Role, User
from apps.accounts.permissions import PERMISSIONS

__all__ = [
    "BlockSerializer",
    "ChangePasswordSerializer",
    "CustomerSerializer",
    "DeviceSerializer",
    "LoginSerializer",
    "PermissionSerializer",
    "RegisterSerializer",
    "RoleSerializer",
    "TokenPairSerializer",
    "UserSerializer",
]


class UserSerializer(serializers.ModelSerializer[User]):
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


class TokenPairSerializer(serializers.Serializer[Any]):
    access = serializers.CharField(read_only=True)
    refresh = serializers.CharField(read_only=True)
    user = UserSerializer(read_only=True)


class RegisterSerializer(serializers.Serializer[Any]):
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


class LoginSerializer(serializers.Serializer[Any]):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_email(self, value: str) -> str:
        return value.strip().lower()


class ChangePasswordSerializer(serializers.Serializer[Any]):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password = serializers.CharField(write_only=True, min_length=8, trim_whitespace=False)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if attrs["current_password"] == attrs["new_password"]:
            raise serializers.ValidationError(
                {"new_password": "Le nouveau mot de passe doit être différent de l'actuel."}
            )
        return attrs


class RefreshSerializer(serializers.Serializer[Any]):
    refresh = serializers.CharField()


# --------------------------------------------------------------- back-office


class CustomerSerializer(serializers.ModelSerializer[User]):
    """Dossier client vu du service client.

    Intégralement en lecture seule : le nom, l'adresse électronique et le
    téléphone sont les données du client, qu'il modifie depuis son application.
    Les rendre éditables ici ouvrirait un chemin pour changer l'adresse d'un
    compte — donc pour en prendre le contrôle par « mot de passe oublié ».

    Le seul geste d'exploitation est le blocage, et il a sa propre route.
    """

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "phone",
            "full_name",
            "avatar",
            "is_active",
            "email_verified_at",
            "phone_verified_at",
            "last_seen_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class BlockSerializer(serializers.Serializer[Any]):
    """Motif du blocage.

    Exigé — et non facultatif : un compte fermé sans motif est un litige qu'on
    ne saura pas instruire six mois plus tard, quand le client rappellera.
    """

    reason = serializers.CharField(max_length=280)


class PermissionSerializer(serializers.Serializer[Any]):
    """Une entrée du registre des permissions.

    Le libellé sort sous `description` et non sous `label` : `label` est un
    attribut de `serializers.Field`, et un champ de ce nom l'écraserait — ce
    que le vérificateur de types signale, à juste titre.
    """

    code = serializers.CharField(read_only=True)
    description = serializers.CharField(read_only=True)


class RoleSerializer(serializers.ModelSerializer[Role]):
    """Rôle et ses permissions.

    La validation contre le registre est ici **en plus** de celle du modèle :
    `Role.save()` lève une `ValidationError` Django, que DRF ne traduit pas —
    elle sortirait en 500. Une faute de frappe (`orders.refunds`) mérite un 400
    qui nomme les valeurs admises, pas une erreur serveur.
    """

    permissions = serializers.ListField(
        child=serializers.CharField(max_length=64), allow_empty=True
    )

    class Meta:
        model = Role
        fields = ["id", "name", "description", "permissions", "is_system", "created_at"]
        read_only_fields = ["id", "is_system", "created_at"]

    def validate_permissions(self, value: list[str]) -> list[str]:
        inconnues = sorted(set(value) - set(PERMISSIONS))
        if inconnues:
            raise serializers.ValidationError(
                f"Permissions inconnues : {', '.join(inconnues)}. "
                f"Valeurs admises : {', '.join(sorted(PERMISSIONS))}."
            )
        # Dédoublonné et trié : deux rôles portant les mêmes droits dans un
        # ordre différent se comparent alors à l'œil, dans un écran d'audit.
        return sorted(set(value))


class DeviceSerializer(serializers.ModelSerializer[Device]):
    platform = serializers.ChoiceField(choices=DevicePlatform.choices)

    # `Device.token` est unique en base, ce dont `ModelSerializer` déduit
    # automatiquement un `UniqueValidator`. Il rejette alors en 400 tout jeton
    # déjà enregistré — or c'est le cas **nominal** : ré-enregistrer un appareil
    # au lancement de l'application, ou le réattribuer quand son propriétaire
    # change de compte. La validation héritée contredisait donc l'upsert que
    # `AuthService.register_device` fait exprès, et la requête n'atteignait
    # jamais le service. On la retire ; l'unicité reste tenue par la contrainte
    # de base, qui est le bon endroit pour elle.
    token = serializers.CharField(max_length=512, validators=[])

    class Meta:
        model = Device
        fields = ["id", "token", "platform", "last_used_at", "created_at"]
        read_only_fields = ["id", "last_used_at", "created_at"]
