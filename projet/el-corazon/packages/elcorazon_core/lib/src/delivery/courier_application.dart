import 'package:elcorazon_core/src/auth/verification_challenge.dart';

/// Ce qu'un candidat livreur soumet à `POST /delivery/apply/` — miroir de
/// `CourierSelfApplicationSerializer`
/// (`backend/apps/delivery/serializers.py`).
///
/// Ni statut de dossier ni compteur : ils n'existent pas en écriture côté
/// serveur, et les porter ici laisserait croire le contraire à qui lit cette
/// classe. Un candidat ne se valide pas lui-même — son dossier naît en attente,
/// et c'est le personnel qui l'instruit (invariant L1).
class CourierApplication {
  const CourierApplication({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.restaurantSlug,
    required this.vehicleType,
    this.vehiclePlate = '',
    this.nationalIdNumber = '',
    this.licenceNumber = '',
  });

  /// Identifiant de connexion, et adresse où part le code de vérification.
  final String email;
  final String password;
  final String fullName;

  /// Obligatoire, et au format international E.164 (`+22890123456`) : c'est le
  /// seul moyen de joindre le candidat pour instruire son dossier, et le
  /// serveur le refuse dans toute autre forme.
  final String phone;

  /// Établissement de rattachement, par son slug — voir
  /// [RestaurantDirectoryRepository], qui rend la liste où le choisir.
  final String restaurantSlug;

  /// `motorcycle` | `bicycle` | `car` | `scooter` (`VehicleType` côté serveur).
  final String vehicleType;

  final String vehiclePlate;
  final String nationalIdNumber;
  final String licenceNumber;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'full_name': fullName,
    'phone': phone,
    'restaurant': restaurantSlug,
    'vehicle_type': vehicleType,
    if (vehiclePlate.isNotEmpty) 'vehicle_plate': vehiclePlate,
    if (nationalIdNumber.isNotEmpty) 'national_id_number': nationalIdNumber,
    if (licenceNumber.isNotEmpty) 'licence_number': licenceNumber,
  };
}

/// Accusé de dépôt d'une candidature — miroir de
/// `CourierApplicationAcceptedSerializer`.
///
/// **Aucun jeton n'en sort**, et c'est le point : la session s'obtient au coup
/// d'après, en présentant le code (`SessionNotifier.verifyAccount`). Un écran
/// qui chercherait ici un `access` chercherait quelque chose que le serveur
/// s'interdit délibérément de rendre.
class CourierApplicationReceipt {
  const CourierApplicationReceipt({
    required this.challenge,
    required this.verificationStatus,
  });

  factory CourierApplicationReceipt.fromJson(Map<String, dynamic> json) {
    return CourierApplicationReceipt(
      challenge: VerificationChallenge.fromJson(json),
      verificationStatus: json['verification_status'] as String,
    );
  }

  /// Où le code est parti, combien de temps il vaut, quand un renvoi devient
  /// possible.
  final VerificationChallenge challenge;

  /// L'état du dossier à sa naissance — `pending`, toujours. Rendu quand même
  /// plutôt que supposé : l'écran suivant dit ce que le serveur dit, et n'aura
  /// rien à réécrire le jour où un autre état devient possible.
  final String verificationStatus;
}
