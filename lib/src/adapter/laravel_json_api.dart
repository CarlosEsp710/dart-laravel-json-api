import 'package:http/http.dart' as http;

import './mixins/http.dart';
import '../exceptions.dart';
import '../interfaces.dart';
import '../serializers/laravel_json_api.dart';

class LaravelJsonApiAdapter extends Adapter with Http {
  final String apiPath;
  late Map<String, Map<String, LaravelJsonApiDocument>> _cache;

  LaravelJsonApiAdapter(
    String hostname,
    this.apiPath, {
    bool useSSL = true,
  }) : super(LaravelJsonApiSerializer()) {
    this.hostname = hostname;
    this.useSSL = useSSL;
    _cache = <String, Map<String, LaravelJsonApiDocument>>{};
    addHeader('Accept', 'application/vnd.api+json');
    addHeader('Content-Type', 'application/vnd.api+json');
  }

  @override
  Future<LaravelJsonApiDocument> find(
    String endpoint,
    String id, {
    bool forceReload = false,
    Map<String, String> queryParams = const {},
  }) async {
    if (forceReload == true || queryParams.isNotEmpty) {
      return _fetchAndCache(endpoint, id, queryParams);
    }
    LaravelJsonApiDocument? cached = peek(endpoint, id);
    if (cached != null) {
      return cached;
    } else {
      return _fetchAndCache(endpoint, id, queryParams);
    }
  }

  Future<LaravelJsonApiDocument> _fetchAndCache(
    String endpoint,
    String id,
    Map<String, String> queryParams,
  ) async {
    LaravelJsonApiDocument fetched = await _fetch(endpoint, id, queryParams);
    cache(endpoint, fetched);
    return fetched;
  }

  Future<LaravelJsonApiDocument> _fetch(
    String endpoint,
    String id,
    Map<String, String> queryParams,
  ) async {
    final response =
        await httpGet("$apiPath/$endpoint/$id", queryParams: queryParams);
    String payload = checkAndDecode(response) ?? '{}';
    return serializer.deserialize(payload) as LaravelJsonApiDocument;
  }

  @override
  Future<LaravelJsonApiManyDocument> findManyById(
    String endpoint,
    Iterable<String> ids, {
    bool forceReload = false,
    Map<String, String> queryParams = const {},
  }) async {
    if (ids.isEmpty) {
      return Future.value(
          LaravelJsonApiManyDocument(<LaravelJsonApiDocument>[]));
    }
    if (forceReload == true || queryParams.isNotEmpty) {
      return await query(endpoint, {...queryParams, ..._idsParam(ids)});
    }
    LaravelJsonApiManyDocument cached = peekMany(endpoint, ids);
    if (cached.length != ids.length) {
      List<LaravelJsonApiDocument> cachedDocs = cached.toList();
      Iterable<String> cachedIds =
          cachedDocs.map((doc) => doc.id).whereType<String>().toList();
      Iterable<String> loadableIds = ids.where((id) => !cachedIds.contains(id));
      LaravelJsonApiManyDocument loaded =
          await query(endpoint, {...queryParams, ..._idsParam(loadableIds)});
      if (cachedDocs.isNotEmpty) loaded.append(cachedDocs);
      return loaded;
    } else {
      return cached;
    }
  }

  @override
  Future<LaravelJsonApiManyDocument> filter(
    String endpoint,
    String filterField,
    Iterable<String> values, {
    bool forceReload = false,
    Map<String, String> queryParams = const {},
  }) async {
    if (values.isEmpty) {
      return Future.value(
          LaravelJsonApiManyDocument(<LaravelJsonApiDocument>[]));
    }
    if (forceReload == true || queryParams.isNotEmpty) {
      return await query(
          endpoint, {...queryParams, ..._filterField(filterField, values)});
    }
    LaravelJsonApiManyDocument cached = peekMany(endpoint, values);
    if (cached.length != values.length) {
      List<LaravelJsonApiDocument> cachedDocs = cached.toList();
      Iterable<String> cachedIds =
          cachedDocs.map((doc) => doc.id).whereType<String>().toList();
      Iterable<String> loadableIds =
          values.where((value) => !cachedIds.contains(value));
      LaravelJsonApiManyDocument loaded = await query(endpoint,
          {...queryParams, ..._filterField(filterField, loadableIds)});
      if (cachedDocs.isNotEmpty) loaded.append(cachedDocs);
      return loaded;
    } else {
      return cached;
    }
  }

  Map<String, String> _filterField(String filterField, Iterable<String> ids) {
    return {'filter[$filterField]': ids.join(',')};
  }

  Map<String, String> _idsParam(Iterable<String> ids) {
    return {'filter[id]': ids.join(',')};
  }

  @override
  Future<LaravelJsonApiManyDocument> findAll(
    String endpoint, {
    Map<String, String> queryParams = const {},
  }) async {
    final response =
        await httpGet("$apiPath/$endpoint", queryParams: queryParams);
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeAndCacheMany(payload, endpoint);
  }

  @override
  Future<LaravelJsonApiManyDocument> getRelated(
      String endpoint, String id, String relationshipName) async {
    final response = await httpGet("$apiPath/$endpoint/$id/$relationshipName");
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeAndCacheMany(payload, endpoint);
  }

  @override
  Future<LaravelJsonApiManyDocument> query(
    String endpoint,
    Map<String, String> params,
  ) async {
    final response = await httpGet("$apiPath/$endpoint", queryParams: params);
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeAndCacheMany(payload, endpoint);
  }

  LaravelJsonApiManyDocument _deserializeAndCacheMany(
    String payload,
    String endpoint,
  ) {
    LaravelJsonApiManyDocument fetched =
        serializer.deserializeMany(payload) as LaravelJsonApiManyDocument;
    cacheMany(endpoint, fetched);
    return fetched;
  }

  @override
  Future<LaravelJsonApiDocument> save(
    String endpoint,
    Object document,
  ) async {
    if (document is! LaravelJsonApiDocument) {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }
    LaravelJsonApiDocument? jsonApiDoc;
    try {
      jsonApiDoc = document;
      http.Response response;

      if (jsonApiDoc.isNew) {
        response = await httpPost("$apiPath/$endpoint",
            body: serializer.serialize(jsonApiDoc));
      } else {
        response = await httpPatch("$apiPath/$endpoint/${jsonApiDoc.id}",
            body: serializer.serialize(jsonApiDoc));
      }
      String payload = checkAndDecode(response) ?? '{}';
      LaravelJsonApiDocument saved =
          serializer.deserialize(payload) as LaravelJsonApiDocument;
      cache(endpoint, saved);
      return saved;
    } on UnprocessableException catch (e) {
      Map parsed =
          (serializer as LaravelJsonApiSerializer).parse(e.responseBody!);
      if (parsed.containsKey('errors')) {
        jsonApiDoc!.errors = parsed['errors'];
        throw InvalidRecordException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<Object> replaceRelationship(
    String endpoint,
    String relationshipName,
    Object document,
    Object relatedDocument,
  ) async {
    if (document is! LaravelJsonApiDocument ||
        relatedDocument is! LaravelJsonApiDocument) {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }

    LaravelJsonApiDocument? jsonApiDoc;
    LaravelJsonApiDocument? jsonApiDocRelated;

    try {
      jsonApiDoc = document;
      jsonApiDocRelated = relatedDocument;
      http.Response response;

      response = await httpPatch(
          "$apiPath/$endpoint/${jsonApiDoc.id}/$relationshipName",
          body: serializer.serialize(jsonApiDocRelated));

      String payload = checkAndDecode(response) ?? '{}';

      LaravelJsonApiDocument saved =
          serializer.deserialize(payload) as LaravelJsonApiDocument;

      cache(endpoint, saved);

      return saved;
    } on UnprocessableException catch (e) {
      Map parsed =
          (serializer as LaravelJsonApiSerializer).parse(e.responseBody!);

      if (parsed.containsKey('errors')) {
        jsonApiDoc!.errors = parsed['errors'];
        throw InvalidRecordException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> delete(String endpoint, Object document) async {
    try {
      unCache(endpoint, document);
      LaravelJsonApiDocument jsonApiDoc = (document as LaravelJsonApiDocument);
      await performDelete(endpoint, jsonApiDoc);
    } on TypeError {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }
  }

  Future<void> performDelete(
    String endpoint,
    LaravelJsonApiDocument jsonApiDoc,
  ) async {
    final response = await httpDelete("$apiPath/$endpoint/${jsonApiDoc.id}");
    checkAndDecode(response);
  }

  @override
  Future<LaravelJsonApiDocument> memberPutAction(
    String endpoint,
    Object document,
    String actionPath,
  ) async {
    if (document is! LaravelJsonApiDocument) {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }
    LaravelJsonApiDocument? jsonApiDoc;
    try {
      jsonApiDoc = document;
      var response = await httpPut(
        "$apiPath/$endpoint/${jsonApiDoc.id}/$actionPath",
        body: serializer.serialize(jsonApiDoc),
      );
      String payload = checkAndDecode(response) ?? '{}';
      LaravelJsonApiDocument updated =
          serializer.deserialize(payload) as LaravelJsonApiDocument;
      cache(endpoint, updated);
      return updated;
    } on UnprocessableException catch (e) {
      Map parsed =
          (serializer as LaravelJsonApiSerializer).parse(e.responseBody!);
      if (parsed.containsKey('errors')) {
        jsonApiDoc!.errors = parsed['errors'];
        throw InvalidRecordException();
      } else {
        rethrow;
      }
    }
  }

  @override
  void cache(String endpoint, Object document) {
    try {
      LaravelJsonApiDocument jsonApiDoc = (document as LaravelJsonApiDocument);
      if (jsonApiDoc.id != null) {
        _cache[endpoint] ??= <String, LaravelJsonApiDocument>{};
        _cache[endpoint]![jsonApiDoc.id!] = jsonApiDoc;
      } else {
        throw CachingException('Cannot cache document with null id');
      }
    } on TypeError {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }
  }

  @override
  void unCache(String endpoint, Object document) {
    try {
      LaravelJsonApiDocument jsonApiDoc = (document as LaravelJsonApiDocument);
      Map<String?, LaravelJsonApiDocument>? docCache = _cache[endpoint];
      if (docCache != null && docCache.containsKey(jsonApiDoc.id)) {
        docCache.remove(jsonApiDoc.id);
      }
    } on TypeError {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }
  }

  @override
  void clearCache() {
    for (var docCache in _cache.values) {
      if (docCache is Map) {
        docCache.clear();
      }
    }
    _cache.clear();
  }

  @override
  void cacheMany(String endpoint, Iterable<Object> documents) {
    for (var document in documents) {
      cache(endpoint, document);
    }
  }

  @override
  LaravelJsonApiDocument? peek(String endpoint, String id) {
    Map<String?, LaravelJsonApiDocument>? docCache = _cache[endpoint];
    return docCache != null ? docCache[id] : null;
  }

  @override
  LaravelJsonApiManyDocument peekMany(String endpoint, Iterable<String> ids) {
    List<LaravelJsonApiDocument> cachedDocs = ids
        .map((id) => peek(endpoint, id))
        .whereType<LaravelJsonApiDocument>()
        .toList();
    return LaravelJsonApiManyDocument(cachedDocs);
  }

  @override
  LaravelJsonApiManyDocument peekAll(String endpoint) {
    Map<String?, LaravelJsonApiDocument>? docCache = _cache[endpoint];
    return LaravelJsonApiManyDocument(
        docCache != null ? docCache.values : <LaravelJsonApiDocument>[]);
  }
}
