class SpotDto {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type;
  final String description;
  final List<String> services;
  final double rating;
  final List<String> photos;

  const SpotDto({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.description,
    required this.services,
    required this.rating,
    required this.photos,
  });

  factory SpotDto.fromJson(Map<String, dynamic> json) {
    return SpotDto(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      type: json['type'] as String,
      description: json['description'] as String? ?? '',
      services: (json['services'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'type': type,
        'description': description,
        'services': services,
        'rating': rating,
        'photos': photos,
      };
}
