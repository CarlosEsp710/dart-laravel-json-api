import 'package:http/http.dart' as http;

import './mixins/http.dart';
import '../exceptions.dart';
import '../interfaces.dart';
import '../serializers/laravel_json_api.dart';

class LaravelJsonApiAdapter extends Adapter with Http {
  final String apiPath;

  LaravelJsonApiAdapter(
    String hostname,
    this.apiPath, {
    bool useSSL = true,
  }) : super(LaravelJsonApiSerializer()) {
    this.hostname = hostname;
    this.useSSL = useSSL;
    addHeader('Accept', 'application/vnd.api+json');
    addHeader('Content-Type', 'application/vnd.api+json');
  }

  @override
  Future<LaravelJsonApiManyDocument> findAll(
    String endpoint, {
    Map<String, String> queryParams = const {},
  }) async {
    final response =
        await httpGet("$apiPath/$endpoint", queryParams: queryParams);
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeMany(payload, endpoint);
  }

  @override
  Future<LaravelJsonApiDocument> find(
    String endpoint,
    String id, {
    Map<String, String> queryParams = const {},
  }) async {
    return _fetch(endpoint, id, queryParams);
  }

  @override
  Future<LaravelJsonApiManyDocument> findManyById(
    String endpoint,
    Iterable<String> ids, {
    Map<String, String> queryParams = const {},
  }) async {
    if (ids.isEmpty) {
      return Future.value(
          LaravelJsonApiManyDocument(<LaravelJsonApiDocument>[]));
    }

    return LaravelJsonApiManyDocument(
        await _query(endpoint, {...queryParams, ..._idsParam(ids)}));
  }

  @override
  Future<LaravelJsonApiManyDocument> filter(
    String endpoint,
    String filterField,
    Iterable<String> values, {
    Map<String, String> queryParams = const {},
  }) async {
    if (values.isEmpty) {
      return Future.value(
          LaravelJsonApiManyDocument(<LaravelJsonApiDocument>[]));
    }

    return LaravelJsonApiManyDocument(await _query(
        endpoint, {...queryParams, ..._filterField(filterField, values)}));
  }

  Map<String, String> _filterField(String filterField, Iterable<String> ids) {
    return {'filter[$filterField]': ids.join(',')};
  }

  Map<String, String> _idsParam(Iterable<String> ids) {
    return {'filter[id]': ids.join(',')};
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

  Future<LaravelJsonApiManyDocument> _query(
    String endpoint,
    Map<String, String> params,
  ) async {
    final response = await httpGet("$apiPath/$endpoint", queryParams: params);
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeMany(payload, endpoint);
  }

  @override
  Future<LaravelJsonApiManyDocument> getRelated(
      String endpoint, String id, String relationshipName) async {
    final response = await httpGet("$apiPath/$endpoint/$id/$relationshipName");
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeMany(payload, endpoint);
  }

  LaravelJsonApiManyDocument _deserializeMany(
    String payload,
    String endpoint,
  ) {
    return LaravelJsonApiManyDocument(
        serializer.deserializeMany(payload) as LaravelJsonApiManyDocument);
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
    String id,
    Object relatedDocument,
  ) async {
    if (relatedDocument is! LaravelJsonApiDocument) {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }
    LaravelJsonApiDocument? jsonApiDocRelated;

    try {
      jsonApiDocRelated = relatedDocument;
      http.Response response;

      response = await httpPatch("$apiPath/$endpoint/$id/$relationshipName",
          body: serializer.serialize(jsonApiDocRelated));

      String payload = checkAndDecode(response) ?? '{}';

      LaravelJsonApiDocument saved =
          serializer.deserialize(payload) as LaravelJsonApiDocument;

      return saved;
    } on UnprocessableException catch (e) {
      Map parsed =
          (serializer as LaravelJsonApiSerializer).parse(e.responseBody!);

      if (parsed.containsKey('errors')) {
        throw InvalidRecordException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future delete(String endpoint, Object document) async {
    if (document is! LaravelJsonApiDocument) {
      throw ArgumentError('Document must be a LaravelJsonApiDocument');
    }
    LaravelJsonApiDocument? jsonApiDoc;
    try {
      jsonApiDoc = document;
      final response = await httpDelete("$apiPath/$endpoint/${jsonApiDoc.id}");
      checkAndDecode(response);

      return response;
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
}
