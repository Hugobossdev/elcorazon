import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/etat_compte.dart';
import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/widgets/custom_button.dart';

/// Le mur affiché quand le compte ne permet pas d'entrer — suspendu, refusé,
/// bloqué.
///
/// ## Pourquoi un mur ici et pas ailleurs
///
/// Un dossier **en attente** n'en justifie pas : le livreur consulte son
/// profil, son historique, ses réglages, et il ne reçoit simplement aucune
/// course — ce que le serveur lui refuse de toute façon (L1). Les trois états
/// traités ici sont d'une autre nature : rien de ce que l'application propose
/// n'a de sens tant qu'ils durent, et laisser entrer donnerait à croire que
/// des courses vont finir par arriver.
///
/// La décision de barrer vit dans [EtatCompte.barreLApplication], pas ici :
/// cet écran affiche, il ne juge pas.
///
/// ## Ce que le bouton « Actualiser » fait vraiment
///
/// Il relit le compte et le dossier auprès du serveur. C'est le seul geste
/// utile : une levée de suspension est une décision d'El Corazón, elle
/// n'arrive par aucune notification, et sans relecture le livreur devrait tuer
/// l'application pour la découvrir.
class AccountStatusScreen extends StatefulWidget {
  const AccountStatusScreen({required this.etat, super.key});

  final EtatCompte etat;

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> {
  bool _enRelecture = false;
  String? _erreur;

  Future<void> _actualiser() async {
    if (_enRelecture) return;
    setState(() {
      _enRelecture = true;
      _erreur = null;
    });

    final app = context.read<AppService>();
    try {
      await app.rechargerCompte();
      // Le dossier ensuite, et séparément : un compte rouvert dont le dossier
      // reste suspendu ne débloque rien, et l'inverse est vrai aussi. Les deux
      // se relisent, l'échec de l'un n'empêche pas l'autre.
      await app.rechargerDossier();
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _enRelecture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppService>();
    final notes = app.courierProfile?.verificationNotes ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(widget.etat.icone, size: 72, color: theme.colorScheme.error),
              const SizedBox(height: 24),
              Text(
                widget.etat.titre,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                widget.etat.explication,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),

              // Le motif rédigé par le personnel au moment de la décision. Il
              // dit ce que la phrase générique ne peut pas dire — quelle pièce
              // manque, quel incident a motivé la suspension — et c'est
              // précisément ce que le livreur appellerait demander.
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Motif', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Text(notes, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],

              if (_erreur != null) ...[
                const SizedBox(height: 20),
                Text(
                  _erreur!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 36),
              CustomButton(
                text: 'Actualiser',
                isLoading: _enRelecture,
                icon: Icons.refresh,
                outlined: true,
                onPressed: _actualiser,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => unawaited(context.read<AppService>().logout()),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
