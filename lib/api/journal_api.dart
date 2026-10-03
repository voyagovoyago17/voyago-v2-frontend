import 'package:dio/dio.dart';
import '../models/journal.dart';
import 'dio_client.dart';
import 'endpoints.dart';

class JournalApi {
  final DioClient _client;

  JournalApi({DioClient? client}) : _client = client ?? DioClient.instance;

  Future<List<JournalTripSummary>> list() async {
    final data = await _client.get(Endpoints.journal);
    return ((data as Map<String, dynamic>)['trips'] as List? ?? [])
        .map((e) => JournalTripSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// « Et maintenant ? » : 3 idées de prochain voyage (générées une fois par l'IA)
  Future<List<NextTripIdea>> nextIdeas(String tripId) async {
    final data = await _client.get(Endpoints.journalNext(tripId)) as Map<String, dynamic>;
    return (data['suggestions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => NextTripIdea.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<JournalDetail> detail(String tripId) async {
    final data = await _client.get(Endpoints.journalDetail(tripId));
    return JournalDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<JournalEntry> saveEntry({
    required String tripId,
    required String poiName,
    required int day,
    String? note,
    List<String>? moodTags,
    bool? visited,
  }) async {
    final data = await _client.put(Endpoints.journalEntries(tripId), data: {
      'poi_name': poiName,
      'day': day,
      if (note != null) 'note': note,
      if (moodTags != null) 'mood_tags': moodTags,
      if (visited != null) 'visited': visited,
    });
    return JournalEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<JournalEntry> addPhoto({
    required String tripId,
    required String poiName,
    required int day,
    required String filePath,
  }) async {
    final form = FormData.fromMap({
      'poi_name': poiName,
      'day': day.toString(),
      'file': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
    });
    final data = await _client.post(
      Endpoints.journalPhotos(tripId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return JournalEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<JournalEntry> removePhoto({required String tripId, required String key}) async {
    final data = await _client.delete(Endpoints.journalPhoto(tripId, key));
    return JournalEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<void> complete(String tripId) => _client.post(Endpoints.journalComplete(tripId));

  Future<void> reopen(String tripId) => _client.post(Endpoints.journalReopen(tripId));

  /// Partage à la communauté ; renvoie l'XP gagnée (0 si déjà partagé).
  Future<int> share(String tripId) async {
    final data = await _client.post(Endpoints.journalShare(tripId));
    return ((data as Map<String, dynamic>)['xp_awarded'] as num?)?.toInt() ?? 0;
  }
}
