import 'package:supabase_flutter/supabase_flutter.dart';

/// One saved thing in the cloud `records` table (see backend/supabase.sql).
class CloudRecord {
  const CloudRecord({required this.kind, required this.id, this.data = const {}, this.deleted = false});
  final String kind;
  final String id;
  final Map<String, dynamic> data;
  final bool deleted;

  String get key => '$kind/$id';

  Map<String, dynamic> toJson() => {'kind': kind, 'id': id, 'data': data, 'deleted': deleted};

  factory CloudRecord.fromJson(Map<String, dynamic> j) => CloudRecord(
        kind: j['kind'] as String,
        id: j['id'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        deleted: j['deleted'] as bool? ?? false,
      );
}

/// Where records are stored. The real one is Supabase; tests use a fake.
abstract class CloudBackend {
  String? get userId;
  Future<List<CloudRecord>> fetchAll();
  Future<void> upsert(List<CloudRecord> records);
  Future<void> deleteEverything();
}

class SupabaseBackend implements CloudBackend {
  SupabaseBackend(this._db);
  final SupabaseClient _db;

  @override
  String? get userId => _db.auth.currentUser?.id;

  @override
  Future<List<CloudRecord>> fetchAll() async {
    final uid = userId;
    if (uid == null) return [];
    const page = 1000; // Supabase returns at most 1000 rows per request.
    final out = <CloudRecord>[];
    for (var from = 0;; from += page) {
      final rows = await _db
          .from('records')
          .select('kind,id,data,deleted')
          .eq('user_id', uid)
          .order('kind')
          .order('id')
          .range(from, from + page - 1);
      out.addAll(rows.map(CloudRecord.fromJson));
      if (rows.length < page) break;
    }
    return out;
  }

  @override
  Future<void> upsert(List<CloudRecord> records) async {
    final uid = userId;
    if (uid == null || records.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    for (var i = 0; i < records.length; i += 500) {
      final chunk = records.skip(i).take(500).map((r) => {
            'user_id': uid,
            'kind': r.kind,
            'id': r.id,
            'data': r.data,
            'deleted': r.deleted,
            'updated_at': now,
          });
      await _db.from('records').upsert(chunk.toList());
    }
  }

  @override
  Future<void> deleteEverything() async {
    final uid = userId;
    if (uid == null) return;
    await _db.from('records').delete().eq('user_id', uid);
  }
}

/// Result of merging this device's data with the cloud on sign-in.
class MergeResult {
  const MergeResult({required this.records, required this.toUpload});

  /// What this device should now hold (no deleted records).
  final Map<String, CloudRecord> records;

  /// Local records the cloud does not have yet.
  final List<CloudRecord> toUpload;
}

/// Cloud wins when both sides have the same record; anything only on this
/// device (added offline or before signing in) is kept and uploaded;
/// anything deleted in the cloud is removed here.
MergeResult mergeRecords({required List<CloudRecord> local, required List<CloudRecord> cloud}) {
  final merged = <String, CloudRecord>{};
  final cloudKeys = <String>{};
  for (final c in cloud) {
    cloudKeys.add(c.key);
    if (!c.deleted) merged[c.key] = c;
  }
  final upload = <CloudRecord>[];
  for (final l in local) {
    if (cloudKeys.contains(l.key)) continue;
    merged[l.key] = l;
    upload.add(l);
  }
  return MergeResult(records: merged, toUpload: upload);
}
