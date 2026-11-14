/// RF-013: calificación de 1 a 5 estrellas con comentario opcional.
class Review {
  final String id;
  final String appointmentId;
  final int rating;
  final String comment;

  const Review({
    required this.id,
    required this.appointmentId,
    required this.rating,
    required this.comment,
  });
}
