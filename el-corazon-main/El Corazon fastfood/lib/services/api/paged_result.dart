/// Résultat paginé générique renvoyé par l'API Laravel (`paginate()`).
class PagedResult<T> {
  PagedResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  /// Construit un résultat paginé à partir d'une réponse Laravel et d'un mapper.
  factory PagedResult.fromResponse(
    Map<String, dynamic> response,
    T Function(Map<String, dynamic>) mapper, {
    int fallbackPage = 1,
  }) {
    final data = (response['data'] as List? ?? []);
    final items = data
        .map((e) => mapper(e as Map<String, dynamic>))
        .toList();

    return PagedResult<T>(
      items: items,
      currentPage: (response['current_page'] as num?)?.toInt() ?? fallbackPage,
      lastPage: (response['last_page'] as num?)?.toInt() ?? fallbackPage,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }
}
