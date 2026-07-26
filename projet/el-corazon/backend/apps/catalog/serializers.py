"""Contrats du catalogue — ADR-009, invariants C1 et S1.

**Le prix est toujours en lecture seule.** Aucun sérialiseur d'entrée ne le
porte, ni ici ni dans le panier ni dans la commande : c'est la traduction
littérale de C1, où l'implémentation précédente acceptait le prix envoyé par le
client et facturait ce qu'on lui disait de facturer.
"""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.accounts.models import User
from apps.catalog.models import Category, MenuItem, Option, OptionGroup, Review
from apps.restaurants.models import Restaurant
from common.serializers import MoneyField

__all__ = [
    "CategorySerializer",
    "MenuItemDetailSerializer",
    "MenuItemSerializer",
    "OptionGroupSerializer",
    "OptionSerializer",
    "ReviewSerializer",
    "ReviewWriteSerializer",
]


class CategorySerializer(serializers.ModelSerializer[Category]):
    restaurant = serializers.SlugRelatedField[Restaurant](slug_field="slug", read_only=True)

    class Meta:
        model = Category
        fields = ["id", "restaurant", "name", "slug", "emoji", "description", "sort_order"]
        read_only_fields = fields


class OptionSerializer(serializers.ModelSerializer[Option]):
    price_delta = MoneyField(read_only=True)

    class Meta:
        model = Option
        fields = ["id", "name", "price_delta", "is_default", "is_available", "sort_order"]
        read_only_fields = fields


class OptionGroupSerializer(serializers.ModelSerializer[OptionGroup]):
    options = OptionSerializer(many=True, read_only=True)
    is_required = serializers.BooleanField(read_only=True)

    class Meta:
        model = OptionGroup
        fields = ["id", "name", "min_select", "max_select", "is_required", "sort_order", "options"]
        read_only_fields = fields


class MenuItemSerializer(serializers.ModelSerializer[MenuItem]):
    """Forme de liste — ce qu'affiche une carte de menu.

    Ni les ingrédients, ni les groupes d'options : une page de vingt articles
    porterait alors des centaines de lignes que l'écran de liste n'affiche pas,
    et le premier chargement du menu s'en trouverait ralenti sur un réseau
    mobile — le seul que ces clients utilisent.
    """

    price = MoneyField(read_only=True)
    restaurant = serializers.SlugRelatedField[Restaurant](slug_field="slug", read_only=True)
    category = serializers.SlugRelatedField[Category](slug_field="slug", read_only=True)
    category_name = serializers.CharField(source="category.name", read_only=True)

    class Meta:
        model = MenuItem
        fields = [
            "id",
            "restaurant",
            "category",
            "category_name",
            "name",
            "slug",
            "description",
            "image",
            "price",
            "preparation_minutes",
            "allergens",
            "dietary_tags",
            "is_available",
            "is_popular",
            "vip_exclusive",
            "rating_average",
            "rating_count",
            "sort_order",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class MenuItemDetailSerializer(MenuItemSerializer):
    option_groups = OptionGroupSerializer(many=True, read_only=True)

    class Meta(MenuItemSerializer.Meta):
        fields = [*MenuItemSerializer.Meta.fields, "ingredients", "calories", "option_groups"]
        read_only_fields = fields


class ReviewAuthorSerializer(serializers.ModelSerializer[User]):
    """Auteur d'un avis, réduit à ce qu'un écran public doit montrer.

    Ni adresse électronique ni téléphone : un avis est lisible sans compte, et
    y joindre le contact de son auteur transformerait la page menu en annuaire
    de clients.
    """

    class Meta:
        model = User
        fields = ["id", "full_name", "avatar"]
        read_only_fields = fields


class ReviewSerializer(serializers.ModelSerializer[Review]):
    user = ReviewAuthorSerializer(read_only=True)

    class Meta:
        model = Review
        fields = [
            "id",
            "menu_item",
            "user",
            "rating",
            "title",
            "comment",
            "is_verified_purchase",
            "helpful_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class ReviewWriteSerializer(serializers.Serializer[Any]):
    """Entrée d'un avis.

    `menu_item` est résolu contre les articles vivants : un article
    logiquement supprimé n'accepte plus d'avis, alors qu'il reste lisible dans
    les commandes passées.

    Ni `user` ni `is_verified_purchase` n'y figurent — le premier vient du
    jeton, le second du serveur (S1). Un champ absent du sérialiseur est un
    champ qu'aucune requête ne peut forcer.
    """

    menu_item = serializers.PrimaryKeyRelatedField(queryset=MenuItem.objects.alive())
    rating = serializers.IntegerField(min_value=1, max_value=5)
    title = serializers.CharField(max_length=120, required=False, allow_blank=True, default="")
    comment = serializers.CharField(required=False, allow_blank=True, default="")
