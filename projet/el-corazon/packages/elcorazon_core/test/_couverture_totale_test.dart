// Fichier généré par `tools/couverture.py` — ne pas modifier à la main.
//
// Il n'exécute rien. Il n'existe que pour importer tout `lib/`, afin que
// `flutter test --coverage` instrumente aussi les fichiers qu'aucun test ne
// touche. Sans lui, `lcov.info` ne décrit que les fichiers déjà testés et le
// pourcentage qui en sort ne veut rien dire.
// ignore_for_file: unused_import

import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:elcorazon_core/src/accounts/admin_role.dart';
import 'package:elcorazon_core/src/accounts/administration_repository.dart';
import 'package:elcorazon_core/src/accounts/customer.dart';
import 'package:elcorazon_core/src/accounts/customer_stats.dart';
import 'package:elcorazon_core/src/analytics/analytics_repository.dart';
import 'package:elcorazon_core/src/analytics/report.dart';
import 'package:elcorazon_core/src/analytics/reporting_repository.dart';
import 'package:elcorazon_core/src/auth/auth_repository.dart';
import 'package:elcorazon_core/src/auth/session.dart';
import 'package:elcorazon_core/src/auth/token_storage.dart';
import 'package:elcorazon_core/src/calls/call.dart';
import 'package:elcorazon_core/src/calls/call_repository.dart';
import 'package:elcorazon_core/src/cart/cart.dart';
import 'package:elcorazon_core/src/cart/cart_repository.dart';
import 'package:elcorazon_core/src/catalog/catalog_repository.dart';
import 'package:elcorazon_core/src/catalog/category.dart';
import 'package:elcorazon_core/src/catalog/managed_catalog_repository.dart';
import 'package:elcorazon_core/src/catalog/managed_category.dart';
import 'package:elcorazon_core/src/catalog/menu_item.dart';
import 'package:elcorazon_core/src/catalog/option_template.dart';
import 'package:elcorazon_core/src/catalog/review.dart';
import 'package:elcorazon_core/src/delivery/assignment.dart';
import 'package:elcorazon_core/src/delivery/assignment_offer.dart';
import 'package:elcorazon_core/src/delivery/courier_profile.dart';
import 'package:elcorazon_core/src/delivery/courier_shift.dart';
import 'package:elcorazon_core/src/delivery/delivery_repository.dart';
import 'package:elcorazon_core/src/delivery/managed_courier_repository.dart';
import 'package:elcorazon_core/src/diagnostics/journal.dart';
import 'package:elcorazon_core/src/directions/directions_repository.dart';
import 'package:elcorazon_core/src/directions/geo_point.dart';
import 'package:elcorazon_core/src/directions/route_info.dart';
import 'package:elcorazon_core/src/gamification/achievement.dart';
import 'package:elcorazon_core/src/gamification/badge.dart';
import 'package:elcorazon_core/src/gamification/challenge.dart';
import 'package:elcorazon_core/src/gamification/gamification_repository.dart';
import 'package:elcorazon_core/src/gamification/managed_gamification_repository.dart';
import 'package:elcorazon_core/src/geography/city.dart';
import 'package:elcorazon_core/src/geography/delivery_zone.dart';
import 'package:elcorazon_core/src/geography/geography_repository.dart';
import 'package:elcorazon_core/src/geography/managed_city.dart';
import 'package:elcorazon_core/src/geography/managed_geography_repository.dart';
import 'package:elcorazon_core/src/geography/zone_resolution.dart';
import 'package:elcorazon_core/src/groupcarts/group_cart.dart';
import 'package:elcorazon_core/src/groupcarts/group_cart_repository.dart';
import 'package:elcorazon_core/src/loyalty/loyalty_repository.dart';
import 'package:elcorazon_core/src/loyalty/points_account.dart';
import 'package:elcorazon_core/src/loyalty/points_entry.dart';
import 'package:elcorazon_core/src/loyalty/reward.dart';
import 'package:elcorazon_core/src/loyalty/reward_redemption.dart';
import 'package:elcorazon_core/src/loyalty/subscription.dart';
import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/models/user.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/api_exception.dart';
import 'package:elcorazon_core/src/notifications/app_notification.dart';
import 'package:elcorazon_core/src/notifications/campaign.dart';
import 'package:elcorazon_core/src/notifications/campaign_repository.dart';
import 'package:elcorazon_core/src/notifications/notification_repository.dart';
import 'package:elcorazon_core/src/orders/managed_order_repository.dart';
import 'package:elcorazon_core/src/orders/order.dart';
import 'package:elcorazon_core/src/orders/order_quote.dart';
import 'package:elcorazon_core/src/orders/order_repository.dart';
import 'package:elcorazon_core/src/payments/payment_repository.dart';
import 'package:elcorazon_core/src/payments/split_payment.dart';
import 'package:elcorazon_core/src/payments/transaction.dart';
import 'package:elcorazon_core/src/profile/address.dart';
import 'package:elcorazon_core/src/profile/address_repository.dart';
import 'package:elcorazon_core/src/promotions/promotion.dart';
import 'package:elcorazon_core/src/promotions/promotion_repository.dart';
import 'package:elcorazon_core/src/realtime/realtime_channel.dart';
import 'package:elcorazon_core/src/realtime/realtime_event.dart';
import 'package:elcorazon_core/src/search/search_repository.dart';
import 'package:elcorazon_core/src/social/post.dart';
import 'package:elcorazon_core/src/social/social_group.dart';
import 'package:elcorazon_core/src/social/social_repository.dart';
import 'package:elcorazon_core/src/support/complaint.dart';
import 'package:elcorazon_core/src/support/return_request.dart';
import 'package:elcorazon_core/src/support/support_repository.dart';
import 'package:elcorazon_core/src/support/support_ticket.dart';
import 'package:elcorazon_core/src/tracking/location_ping.dart';
import 'package:elcorazon_core/src/tracking/tracking_repository.dart';

void main() {}
