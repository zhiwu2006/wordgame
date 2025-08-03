enum CardStatus { visible, selected, mismatched, matched }

class GameCard {
  final String id;
  final String text;
  final int pairId;
  CardStatus status;
  final String color;

  GameCard({
    required this.id,
    required this.text,
    required this.pairId,
    this.status = CardStatus.visible,
    required this.color,
  });
}
