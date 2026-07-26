import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/call_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/screens/client/call_screen.dart';

/// Widget qui écoute les appels entrants et affiche une notification
class IncomingCallHandler extends StatefulWidget {
  final Widget child;

  const IncomingCallHandler({
    required this.child,
    super.key,
  });

  @override
  State<IncomingCallHandler> createState() => _IncomingCallHandlerState();
}

class _IncomingCallHandlerState extends State<IncomingCallHandler> {
  final CallService _callService = CallService();
  StreamSubscription<Call>? _incomingCallSubscription;
  Call? _pendingCall;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCallService();
  }

  Future<void> _initializeCallService() async {
    // Attendre que l'utilisateur soit connecté
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final appService = Provider.of<AppService>(context, listen: false);
      if (appService.isLoggedIn &&
          appService.currentUser != null &&
          !_isInitialized) {
        _callService.initialize(userId: appService.currentUser!.id);
        _listenToIncomingCalls();
        _isInitialized = true;
      }
    });
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  void _listenToIncomingCalls() {
    _incomingCallSubscription = _callService.incomingCallStream.listen((call) {
      if (mounted) {
        _showIncomingCallDialog(call);
      }
    });
  }

  void _showIncomingCallDialog(Call call) {
    if (!mounted) return;

    _pendingCall = call;

    final dialogContext = context;
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📞 Appel entrant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              call.callerName ?? 'Livreur',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commande #${call.orderId.substring(0, 8)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectCall(call);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Rejeter'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _acceptCall(call);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );

    // Auto-rejeter après 30 secondes si pas de réponse
    Timer(const Duration(seconds: 30), () {
      if (mounted && _pendingCall?.id == call.id) {
        Navigator.of(dialogContext).pop();
        _rejectCall(call);
      }
    });
  }

  Future<void> _acceptCall(Call call) async {
    _pendingCall = null;
    if (!mounted) return;

    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            orderId: call.orderId,
            callerName: call.callerName,
            receiverName: call.receiverName,
            direction: CallDirection.incoming,
            existingCall: call,
          ),
        ),
      ),
    );
  }

  Future<void> _rejectCall(Call call) async {
    _pendingCall = null;
    await _callService.rejectCall(call);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
