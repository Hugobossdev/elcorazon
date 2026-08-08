// Fichier généré par `tools/couverture.py` — ne pas modifier à la main.
//
// Il n'exécute rien. Il n'existe que pour importer tout `lib/`, afin que
// `flutter test --coverage` instrumente aussi les fichiers qu'aucun test ne
// touche. Sans lui, `lcov.info` ne décrit que les fichiers déjà testés et le
// pourcentage qui en sort ne veut rien dire.
// ignore_for_file: unused_import

import 'package:admin/core/constants/admin_constants.dart';
import 'package:admin/core/utils/admin_helpers.dart';
import 'package:admin/dialogs/notifications_dialog.dart';
import 'package:admin/main.dart';
import 'package:admin/models/order.dart';
import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/presentation/couleur_statut.dart';
import 'package:admin/presentation/dialogues/assignation_livreur.dart';
import 'package:admin/presentation/dialogues/changement_statut.dart';
import 'package:admin/presentation/dialogues/details_commande.dart';
import 'package:admin/presentation/documents_livreur.dart';
import 'package:admin/presentation/evolution_commandes.dart';
import 'package:admin/presentation/onglets/statistiques_commandes.dart';
import 'package:admin/presentation/regimes_article.dart';
import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/presentation/tri_commandes.dart';
import 'package:admin/repositories/django_order_mapper.dart';
import 'package:admin/screens/admin/active_deliveries_screen.dart';
import 'package:admin/screens/admin/admin_dashboard_screen.dart';
import 'package:admin/screens/admin/admin_navigation_screen.dart';
import 'package:admin/screens/admin/admin_roles_screen.dart';
import 'package:admin/screens/admin/advanced_order_management_screen.dart';
import 'package:admin/screens/admin/analytics_screen.dart';
import 'package:admin/screens/admin/category_management_screen.dart';
import 'package:admin/screens/admin/client_management_screen.dart';
import 'package:admin/screens/admin/customization_association_dialog.dart';
import 'package:admin/screens/admin/customization_management_screen.dart';
import 'package:admin/screens/admin/customization_option_form_dialog.dart';
import 'package:admin/screens/admin/driver_assignment_dialog.dart';
import 'package:admin/screens/admin/driver_detailed_stats_screen.dart';
import 'package:admin/screens/admin/driver_document_validation_screen.dart';
import 'package:admin/screens/admin/driver_documents_dashboard_screen.dart';
import 'package:admin/screens/admin/driver_form_dialog.dart';
import 'package:admin/screens/admin/driver_history_screen.dart';
import 'package:admin/screens/admin/driver_management_screen.dart';
import 'package:admin/screens/admin/driver_map_screen.dart';
import 'package:admin/screens/admin/driver_schedule_screen.dart';
import 'package:admin/screens/admin/gamification_management_screen.dart';
import 'package:admin/screens/admin/global_search_screen.dart';
import 'package:admin/screens/admin/marketing_screen.dart';
import 'package:admin/screens/admin/menu_item_form_dialog.dart';
import 'package:admin/screens/admin/menu_management_screen.dart';
import 'package:admin/screens/admin/option_groups_editor.dart';
import 'package:admin/screens/admin/order_management_screen.dart';
import 'package:admin/screens/admin/promotions_screen.dart';
import 'package:admin/screens/admin/send_notification_dialog.dart';
import 'package:admin/screens/admin/settings_screen.dart';
import 'package:admin/screens/admin/zone_form_dialog.dart';
import 'package:admin/screens/admin/zone_selection_tab.dart';
import 'package:admin/screens/auth/admin_auth_screen.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/analytics_service.dart';
import 'package:admin/services/app_service.dart';
import 'package:admin/services/category_management_service.dart';
import 'package:admin/services/client_management_service.dart';
import 'package:admin/services/customization_management_service.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/driver_document_service.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/driver_schedule_service.dart';
import 'package:admin/services/gamification_service.dart';
import 'package:admin/services/geocoding_service.dart';
import 'package:admin/services/global_search_service.dart';
import 'package:admin/services/marketing_service.dart';
import 'package:admin/services/menu_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/services/payments_service.dart';
import 'package:admin/services/promotion_service.dart';
import 'package:admin/services/role_management_service.dart';
import 'package:admin/theme/modern_theme.dart';
import 'package:admin/ui/admin_color_tokens.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:admin/widgets/custom_bar_chart.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';
import 'package:admin/widgets/loading_widget.dart';
import 'package:admin/widgets/modern/enhanced_stat_card.dart';
import 'package:admin/widgets/modern/modern_button.dart';
import 'package:admin/widgets/modern/modern_card.dart';
import 'package:admin/widgets/order_timeline_widget.dart';

void main() {}
