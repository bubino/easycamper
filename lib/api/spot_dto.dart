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
    final lat = (json['latitude'] ?? json['lat']) as num?;
    final lng = (json['longitude'] ?? json['lng']) as num?;

    // Backend services is an object map, mock is a list
    final servicesRaw = json['services'];
    final services = <String>[];
    if (servicesRaw is List) {
      services.addAll(servicesRaw.map((e) => e.toString()));
    } else if (servicesRaw is Map) {
      servicesRaw.forEach((k, v) {
        if (v == true) services.add(k.toString());
      });
    }

    final photosRaw = json['photos'];
    final photos = (photosRaw is List)
        ? photosRaw.map((e) => e.toString()).toList()
        : const <String>[];

    return SpotDto(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '',
      lat: (lat ?? 0).toDouble(),
      lng: (lng ?? 0).toDouble(),
      type: (json['type'] as String?) ?? 'area_sosta',
      description: (json['description'] ?? json['shortDescription'] ?? '') as String,
      services: services,
      rating: ((json['ratingAverage'] ?? json['rating']) as num?)?.toDouble() ?? 0.0,
      photos: photos,
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
