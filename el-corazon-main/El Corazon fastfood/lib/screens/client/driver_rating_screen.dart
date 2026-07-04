import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/driver_rating_service.dart';
import 'package:elcora_fast/widgets/custom_button.dart';

class DriverRatingScreen extends StatefulWidget {
  final String orderId;
  final String driverId;
  final String? driverName;

  const DriverRatingScreen({
    required this.orderId,
    required this.driverId,
    this.driverName,
    super.key,
  });

  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  final _commentController = TextEditingController();
  final _ratingService = DriverRatingService();
  double _rating = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une note')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final success = await _ratingService.submitRating(
        driverId: widget.driverId,
        orderId: widget.orderId,
        customerId: appService.currentUser?.id ?? '',
        rating: _rating.toInt(),
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Merci pour votre avis !')),
          );
          Navigator.of(context).pop(); // Close screen
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'envoi de l\'avis')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Une erreur est survenue')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noter le livreur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, size: 40, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              widget.driverName ?? 'Livreur',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comment s\'est passée la livraison ?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            RatingBar.builder(
              minRating: 1,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Laissez un commentaire (optionnel)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Envoyer',
              onPressed: _submitRating,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

