import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/messages_erreur.dart';

/// Les notes internes d'une fiche — commande ou client — et le champ pour en
/// ajouter une.
///
/// Le cahier des charges les demande aux deux endroits (§4.2.4 « notes », §4.2.6
/// « notes et commentaires »), et l'état des fonctionnalités cochait celles des
/// commandes : il n'en existait aucune. `Order.notes` est la note **du client**
/// sur une ligne ; rien ne permettait à l'équipe de se passer le relais.
///
/// Le widget ne sait rien de l'objet annoté : il reçoit de quoi lire et de quoi
/// écrire. C'est ce qui lui permet de servir aux deux fiches sans les connaître.
class NotesInternes extends StatefulWidget {
  const NotesInternes({
    required this.lire,
    required this.ajouter,
    this.peutEcrire = true,
    super.key,
  });

  final Future<List<eccore.InternalNote>> Function() lire;
  final Future<eccore.InternalNote> Function(String contenu) ajouter;
  final bool peutEcrire;

  @override
  State<NotesInternes> createState() => _NotesInternesState();
}

class _NotesInternesState extends State<NotesInternes> {
  final _saisie = TextEditingController();
  List<eccore.InternalNote> _notes = const [];
  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final notes = await widget.lire();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _chargement = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = messageErreur(e);
        _chargement = false;
      });
    }
  }

  Future<void> _ajouter() async {
    final contenu = _saisie.text.trim();
    if (contenu.isEmpty || _envoi) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final note = await widget.ajouter(contenu);
      if (!mounted) return;
      setState(() {
        _notes = [..._notes, note];
        _saisie.clear();
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            const Text('Notes internes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(
              'jamais vues du client',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_chargement)
          const LinearProgressIndicator()
        else if (_notes.isEmpty)
          Text('Aucune note.', style: TextStyle(color: theme.hintColor))
        else
          for (final note in _notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${note.authorName ?? 'Compte retiré'} · ${_date(note.createdAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  ),
                  SelectableText(note.content),
                ],
              ),
            ),
        if (_erreur != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_erreur!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (widget.peutEcrire) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _saisie,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ajouter une note pour l’équipe…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Ajouter',
                onPressed: _envoi ? null : _ajouter,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _date(DateTime date) {
    final local = date.toLocal();
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(local.day)}/${deux(local.month)} ${deux(local.hour)}:${deux(local.minute)}';
  }
}
