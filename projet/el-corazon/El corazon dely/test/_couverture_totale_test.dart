// Fichier généré par `tools/couverture.py` — ne pas modifier à la main.
//
// Il n'exécute rien. Il n'existe que pour importer tout `lib/`, afin que
// `flutter test --coverage` instrumente aussi les fichiers qu'aucun test ne
// touche. Sans lui, `lcov.info` ne décrit que les fichiers déjà testés et le
// pourcentage qui en sort ne veut rien dire.
// ignore_for_file: unused_import

import 'package:elcora_dely/config/api_config.dart';
import 'package:elcora_dely/firebase_options.dart';
import 'package:elcora_dely/l10n/app_localizations.dart';
import 'package:elcora_dely/l10n/app_localizations_en.dart';
import 'package:elcora_dely/l10n/app_localizations_fr.dart';
import 'package:elcora_dely/main.dart';
import 'package:elcora_dely/models/address.dart';
import 'package:elcora_dely/models/message.dart';
import 'package:elcora_dely/models/order.dart';
import 'package:elcora_dely/models/user.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/screens/auth/driver_auth_screen.dart';
import 'package:elcora_dely/screens/communication/call_screen.dart';
import 'package:elcora_dely/screens/communication/chat_screen.dart';
import 'package:elcora_dely/screens/delivery/address_management_screen.dart';
import 'package:elcora_dely/screens/delivery/analytics_screen.dart';
import 'package:elcora_dely/screens/delivery/delivery_home_screen.dart';
import 'package:elcora_dely/screens/delivery/delivery_navigation_screen.dart';
import 'package:elcora_dely/screens/delivery/delivery_orders_screen.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/delivery/real_time_tracking_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcora_dely/screens/payments/driver_payment_screen.dart';
import 'package:elcora_dely/screens/payments/earnings_screen.dart';
import 'package:elcora_dely/screens/splash_screen.dart';
import 'package:elcora_dely/services/address_service.dart';
import 'package:elcora_dely/services/agora_call_service.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/chat_service.dart';
import 'package:elcora_dely/services/directions_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/services/gamification_service.dart';
import 'package:elcora_dely/services/geocoding_service.dart';
import 'package:elcora_dely/services/location_service.dart';
import 'package:elcora_dely/services/notification_service.dart';
import 'package:elcora_dely/services/performance_service.dart';
import 'package:elcora_dely/services/realtime_tracking_service.dart';
import 'package:elcora_dely/theme.dart';
import 'package:elcora_dely/utils/price_formatter.dart';
import 'package:elcora_dely/utils/validators.dart';
import 'package:elcora_dely/widgets/custom_button.dart';
import 'package:elcora_dely/widgets/custom_text_field.dart';
import 'package:elcora_dely/widgets/el_corazon_logo.dart';
import 'package:elcora_dely/widgets/loading_widget.dart';

void main() {}
