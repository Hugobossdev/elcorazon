import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/delivery/assignment.dart';
import 'package:elcorazon_core/src/delivery/courier_profile.dart';
import 'package:elcorazon_core/src/delivery/courier_shift.dart';

/// Flotte vue par le personnel — `/api/v1/delivery/couriers/` et
/// `/api/v1/delivery/orders/{id}/offer/`
/// (`backend/apps/delivery/views.py`).
///
/// Séparé de [DeliveryRepository], qui est le point de vue du **livreur** : ces
/// routes demandent des permissions nommées (`couriers.read`, `couriers.write`,
/// `couriers.approve`, `couriers.suspend`, `orders.assign_courier`) qu'un compte
/// livreur n'a pas. Les mélanger laisserait croire le contraire.
class ManagedCourierRepository {
  ManagedCourierRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Livreurs des établissements auxquels le compte est rattaché — le filtre
  /// est celui du serveur.
  Future<List<CourierProfile>> list({String? verificationStatus, bool? isOnline}) async {
    final couriers = <CourierProfile>[];
    String? path = '/delivery/couriers/';
    Map<String, dynamic>? queryParameters = {
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (isOnline != null) 'is_online': isOnline.toString(),
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      couriers.addAll(
        results.map((json) => CourierProfile.fromJson(json as Map<String, dynamic>)),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return couriers;
  }

  Future<CourierProfile> getById(String courierId) async {
    final response = await apiClient.get('/delivery/couriers/$courierId/');
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ouvre un compte livreur **et** son dossier, en une requête
  /// (permission `couriers.write`).
  ///
  /// Les deux ensemble parce que c'est un seul geste : deux écrans séparés
  /// laisseraient régulièrement des comptes de type livreur sans dossier —
  /// c'est-à-dire des gens qui se connectent et ne trouvent rien.
  ///
  /// Les pièces justificatives ne sont pas ici : c'est le livreur qui les
  /// dépose depuis son application, et c'est bien lui qui les a.
  Future<CourierProfile> provision({
    required String email,
    required String password,
    required String fullName,
    required String restaurantSlug,
    required String vehicleType,
    String phone = '',
    String vehiclePlate = '',
    String nationalIdNumber = '',
    String licenceNumber = '',
  }) async {
    final response = await apiClient.post(
      '/delivery/couriers/',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'restaurant': restaurantSlug,
        'vehicle_type': vehicleType,
        if (phone.isNotEmpty) 'phone': phone,
        if (vehiclePlate.isNotEmpty) 'vehicle_plate': vehiclePlate,
        if (nationalIdNumber.isNotEmpty) 'national_id_number': nationalIdNumber,
        if (licenceNumber.isNotEmpty) 'licence_number': licenceNumber,
      },
    );
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Instruit ou suspend un dossier.
  ///
  /// **Deux permissions distinctes derrière une seule route** :
  /// `couriers.approve` instruit (valider, rejeter, remettre en attente),
  /// `couriers.suspend` retire du service quelqu'un qui travaillait. C'est le
  /// statut demandé qui départage — les deux gestes n'ont ni la même urgence ni
  /// le même auteur.
  Future<CourierProfile> setVerification({
    required String courierId,
    required String status,
    String notes = '',
  }) async {
    final response = await apiClient.post(
      '/delivery/couriers/$courierId/verification/',
      data: {'status': status, if (notes.isNotEmpty) 'notes': notes},
    );
    return CourierProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Livreurs éligibles pour une commande, **du plus proche au plus loin**.
  ///
  /// L'éligibilité (L1 : en ligne, dossier validé, compte actif) est calculée
  /// par le serveur. La recomposer ici en oubliant un terme est exactement ce
  /// que cette route évite.
  Future<List<CourierProfile>> availableFor(String orderId) async {
    final response = await apiClient.get('/delivery/couriers/available/$orderId/');
    return (response.data as List<dynamic>)
        .map((json) => CourierProfile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Propose la course d'une commande à un livreur
  /// (permission `orders.assign_courier`).
  ///
  /// « Proposer », pas « assigner » : le livreur accepte ou refuse. Écrire un
  /// identifiant de livreur sur la commande, comme le faisait le back-office
  /// Supabase, affectait quelqu'un sans lui demander — et sans vérifier qu'il
  /// pouvait travailler.
  Future<Assignment> offer({required String orderId, required String courierId}) async {
    final response = await apiClient.post(
      '/delivery/orders/$orderId/offer/',
      data: {'courier': courierId},
    );
    return Assignment.fromJson(response.data as Map<String, dynamic>);
  }

  /// Annule une course engagée — distinct du refus par le livreur, et seule
  /// l'annulation incrémente son compteur d'annulations.
  Future<Assignment> cancelAssignment({
    required String assignmentId,
    required String reason,
  }) async {
    final response = await apiClient.post(
      '/delivery/assignments/$assignmentId/cancel/',
      data: {'reason': reason},
    );
    return Assignment.fromJson(response.data as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- planning

  /// Créneaux planifiés — **indicatifs**, ils ne conditionnent aucune course
  /// (voir [CourierShift]).
  Future<List<CourierShift>> shifts({String? courierId, int? dayOfWeek}) async {
    final creneaux = <CourierShift>[];
    String? path = '/delivery/shifts/';
    Map<String, dynamic>? queryParameters = {
      if (courierId != null) 'courier': courierId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek.toString(),
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      creneaux.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => CourierShift.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return creneaux;
  }

  Future<CourierShift> createShift({
    required String courierId,
    required int dayOfWeek,
    required int startMinutes,
    required int endMinutes,
    bool isAvailable = true,
  }) async {
    final response = await apiClient.post(
      '/delivery/shifts/',
      data: {
        'courier': courierId,
        'day_of_week': dayOfWeek,
        'start_time': CourierShift.formatTime(startMinutes),
        'end_time': CourierShift.formatTime(endMinutes),
        'is_available': isAvailable,
      },
    );
    return CourierShift.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CourierShift> updateShift({
    required String shiftId,
    int? dayOfWeek,
    int? startMinutes,
    int? endMinutes,
    bool? isAvailable,
  }) async {
    final response = await apiClient.patch(
      '/delivery/shifts/$shiftId/',
      data: {
        if (dayOfWeek != null) 'day_of_week': dayOfWeek,
        if (startMinutes != null) 'start_time': CourierShift.formatTime(startMinutes),
        if (endMinutes != null) 'end_time': CourierShift.formatTime(endMinutes),
        if (isAvailable != null) 'is_available': isAvailable,
      },
    );
    return CourierShift.fromJson(response.data as Map<String, dynamic>);
  }

  /// Retire une ligne du planning.
  ///
  /// Exposé, contrairement aux suppressions des autres back-offices : un
  /// créneau n'est pas une pièce comptable, rien n'y renvoie. Une **absence**
  /// ponctuelle, elle, se marque avec `isAvailable` — elle se lit alors dans le
  /// planning au lieu d'en disparaître.
  Future<void> deleteShift(String shiftId) async {
    await apiClient.delete('/delivery/shifts/$shiftId/');
  }
}
