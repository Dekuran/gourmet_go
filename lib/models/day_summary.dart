/// Computed end-of-day rating using a 3-factor weighted score.
///
/// Factors: speed (30%), skill (30%), fulfilment (40%).
/// Result: 1-5 stars.
class DaySummary {
  final int ordersServed;
  final int ordersMissed;
  final double avgServiceTimeSeconds;
  final double speedScore;
  final double skillScore;
  final double fulfilmentScore;
  final int stars;

  const DaySummary({
    required this.ordersServed,
    required this.ordersMissed,
    required this.avgServiceTimeSeconds,
    required this.speedScore,
    required this.skillScore,
    required this.fulfilmentScore,
    required this.stars,
  });

  /// Compute a day summary from raw stats.
  ///
  /// [avgCookTime] in seconds, [chefCookCapacity] is the skill-based
  /// cook time for comparison. [totalCustomers] is served + missed.
  factory DaySummary.compute({
    required int ordersServed,
    required int ordersMissed,
    required double avgServiceTimeSeconds,
    required int chefCookCapacity,
  }) {
    final totalCustomers = ordersServed + ordersMissed;

    // Speed: ratio of chef capacity to actual avg time (capped at 1.0)
    final speedScore = avgServiceTimeSeconds > 0
        ? (chefCookCapacity / avgServiceTimeSeconds).clamp(0.0, 1.0)
        : 0.0;

    // Skill: bonus for serving quickly (under 1.5x chef capacity)
    final skillScore = avgServiceTimeSeconds > 0
        ? (1.0 -
                ((avgServiceTimeSeconds - chefCookCapacity) /
                        chefCookCapacity)
                    .clamp(0.0, 1.0))
            .clamp(0.0, 1.0)
        : 0.0;

    // Fulfilment: ratio of served to total customers
    final fulfilmentScore =
        totalCustomers > 0 ? ordersServed / totalCustomers : 0.0;

    // Weighted score: speed 30%, skill 30%, fulfilment 40%
    final weighted =
        speedScore * 0.3 + skillScore * 0.3 + fulfilmentScore * 0.4;

    // Map to 1-5 stars
    final stars = switch (weighted) {
      >= 0.9 => 5,
      >= 0.7 => 4,
      >= 0.5 => 3,
      >= 0.3 => 2,
      _ => 1,
    };

    return DaySummary(
      ordersServed: ordersServed,
      ordersMissed: ordersMissed,
      avgServiceTimeSeconds: avgServiceTimeSeconds,
      speedScore: speedScore,
      skillScore: skillScore,
      fulfilmentScore: fulfilmentScore,
      stars: stars,
    );
  }

  /// Sous chef debrief line based on star rating.
  String get debriefLine => switch (stars) {
        5 => 'Masterful! Every bowl was perfection.',
        4 => 'Great work, chef! Almost flawless service.',
        3 => 'Solid day. Room to sharpen up.',
        2 => 'Rough shift. Let\'s regroup tomorrow.',
        _ => 'We\'ll get \'em next time, chef.',
      };
}
