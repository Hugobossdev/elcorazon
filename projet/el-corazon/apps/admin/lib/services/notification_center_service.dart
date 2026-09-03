import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/services/admin_auth_service.dart';

/// Centre de notifications du back-office — `/api/v1/notifications/`.
///
/// ## Ce qu'il remplace
///
/// `NotificationsDialog` **fabriquait ses propres lignes** à partir de la liste
/// de commandes déjà chargée à l'écran :
///
/// ```dart
/// if (pendingOrders.isNotEmpty) {
///   notifications.add({'title': 'Commandes en attente', …});
/// }
/// for (final order in recentOrders.take(3)) { … }
/// ```
///
/// Ce n'étaient pas des notifications, mais une relecture de l'état courant
/// présentée comme des événements. Trois conséquences, toutes visibles à
/// l'usage : rien n'apparaissait tant que l'écran n'avait pas rechargé ses
/// commandes ; une commande annulée pendant la nuit ne laissait aucune trace,
/// puisque seules les cinq dernières étaient parcourues ; et « lu » n'existait
/// pas — la liste se recomposait identique à chaque ouverture.
///
/// Le serveur, lui, produit de vraies notifications depuis toujours
/// (`apps/notifications`), horodatées et persistantes. Le back-office est la
/// seule des trois applications qui ne les lisait pas.
///
/// ## Ce qu'il n'est pas
///
/// Ce n'est **pas** du push. L'application d'administration n'a pas de projet
/// Firebase déclaré (voir `docs/firebase.md`) : elle relit à l'ouverture, et
/// rien ne vibre. Ce qui suit fonctionne sans FCM, et fonctionnera à
/// l'identique le jour où FCM s'ajoutera — c'est la même source.
///
/// ## Le filtrage des destinataires n'est pas ici
///
/// Le serveur n'adresse à un membre du personnel que ce qui le concerne :
/// l'établissement auquel il est rattaché et les permissions qu'il détient
/// (`staff_to_alert`). Ce service ne filtre rien et n'a rien à filtrer — il lit
/// ce que `/notifications/` rend, qui est déjà la liste de l'appelant.
class NotificationCenterService extends ChangeNotifier {
  /// Instance unique, comme `AdminAuthService` : la déconnexion doit pouvoir
  /// vider ce centre depuis l'extérieur de l'arbre de widgets, et un second
  /// exemplaire viderait un état que personne n'affiche.
  factory NotificationCenterService() => _instance;
  NotificationCenterService._internal();

  static final NotificationCenterService _instance =
      NotificationCenterService._internal();

  eccore.NotificationRepository get _notifications =>
      eccore.NotificationRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.AppNotification> _items = const [];
  int _unread = 0;
  bool _isLoading = false;
  String? _error;

  List<eccore.AppNotification> get notifications => _items;
  int get unreadCount => _unread;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Recharge l'historique et le compteur.
  ///
  /// Le compteur vient de sa **propre route** et non d'un décompte sur la
  /// liste : celle-ci est paginée, et compter les non-lues d'une page donnerait
  /// un nombre faux dès la vingt-et-unième.
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _notifications.getNotifications();
      _unread = await _notifications.getUnreadCount();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('NotificationCenterService: lecture impossible — ${e.code}');
    } catch (e) {
      _error = 'Notifications indisponibles.';
      eccore.Journal.trace('NotificationCenterService: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marque une notification lue.
  ///
  /// L'état local est corrigé avec ce que le serveur rend, pas avec ce qu'on
  /// suppose : relire une notification déjà lue n'écrase pas sa date de
  /// première lecture, et l'inventer ici ferait diverger les deux.
  Future<void> markRead(String id) async {
    try {
      final maj = await _notifications.markRead(id);
      _items = [
        for (final item in _items)
          if (item.id == maj.id) maj else item,
      ];
      _unread = _items.where((item) => !item.isRead).length;
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('NotificationCenterService: marquage impossible — ${e.code}');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _notifications.markAllRead();
      final maintenant = DateTime.now();
      _items = [for (final item in _items) item.isRead ? item : item.asRead(maintenant)];
      _unread = 0;
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('NotificationCenterService: marquage global impossible — ${e.code}');
    }
  }

  /// Vide l'état à la déconnexion — les notifications d'un compte ne se
  /// montrent pas au suivant.
  void clearSession() {
    _items = const [];
    _unread = 0;
    _error = null;
    notifyListeners();
  }
}
