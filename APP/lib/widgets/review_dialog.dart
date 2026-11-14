import 'package:flutter/material.dart';

import '../app_theme.dart';

class ReviewResult {
  final int rating;
  final String comment;

  const ReviewResult(this.rating, this.comment);
}

/// RF-013: 1 a 5 estrellas y comentario opcional. Devuelve null si cancela.
Future<ReviewResult?> showReviewDialog(BuildContext context) {
  return showDialog<ReviewResult>(
    context: context,
    builder: (dialogContext) => const _ReviewDialog(),
  );
}

class StarRating extends StatelessWidget {
  final int rating;
  final double size;

  const StarRating({super.key, required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
      ],
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final commentController = TextEditingController();

  int rating = 0;
  String? error;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Califica tu servicio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 38,
                    tooltip: '$i',
                    onPressed: () {
                      setState(() {
                        rating = i;
                        error = null;
                      });
                    },
                    icon: Icon(
                      i <= rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: commentController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            if (rating == 0) {
              setState(() {
                error = 'Elige de 1 a 5 estrellas';
              });
              return;
            }

            Navigator.pop(
              context,
              ReviewResult(rating, commentController.text.trim()),
            );
          },
          child: const Text(
            'Enviar',
            style: TextStyle(color: primaryColor),
          ),
        ),
      ],
    );
  }
}
