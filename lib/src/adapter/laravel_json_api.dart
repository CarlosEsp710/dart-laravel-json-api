import 'package:http/http.dart' as http;

import './mixins/http.dart';
import '../exceptions.dart';
import '../interfaces.dart';
import '../serializers/laravel_json_api.dart';

class ApiController extends Adapter with Http {
  final String apiPath;

  ApiController(
    String hostname,
    this.apiPath, {
    bool useSSL = true,
  }) : super(Serializer()) {
    this.hostname = hostname;
    this.useSSL = useSSL;
    addHeader('Accept', 'application/vnd.api+json');
    addHeader('Content-Type', 'application/vnd.api+json');
  }

  @override
  Future<ResourceCollection> findAll(
    String endpoint, {
    Map<String, String> queryParams = const {},
  }) async {
    final response =
        await httpGet("$apiPath/$endpoint", queryParams: queryParams);
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeMany(payload, endpoint);
  }

  @override
  Future<ResourceObject> find(
    String endpoint,
    String id, {
    Map<String, String> queryParams = const {},
  }) async {
    return _fetch(endpoint, id, queryParams);
  }

  @override
  Future<ResourceCollection> findManyById(
    String endpoint,
    Iterable<String> ids, {
    Map<String, String> queryParams = const {},
  }) async {
    if (ids.isEmpty) {
      return Future.value(ResourceCollection(<ResourceObject>[]));
    }

    return ResourceCollection(
        await _query(endpoint, {...queryParams, ..._idsParam(ids)}));
  }

  @override
  Future<ResourceCollection> filter(
    String endpoint,
    String filterField,
    Iterable<String> values, {
    Map<String, String> queryParams = const {},
  }) async {
    if (values.isEmpty) {
      return Future.value(ResourceCollection(<ResourceObject>[]));
    }

    return ResourceCollection(await _query(
        endpoint, {...queryParams, ..._filterField(filterField, values)}));
  }

  Map<String, String> _filterField(String filterField, Iterable<String> ids) {
    return {'filter[$filterField]': ids.join(',')};
  }

  Map<String, String> _idsParam(Iterable<String> ids) {
    return {'filter[id]': ids.join(',')};
  }

  Future<ResourceObject> _fetch(
    String endpoint,
    String id,
    Map<String, String> queryParams,
  ) async {
    final response =
        await httpGet("$apiPath/$endpoint/$id", queryParams: queryParams);
    String payload = checkAndDecode(response) ?? '{}';
    return formatter.deserialize(payload) as ResourceObject;
  }

  Future<ResourceCollection> _query(
    String endpoint,
    Map<String, String> params,
  ) async {
    final response = await httpGet("$apiPath/$endpoint", queryParams: params);
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeMany(payload, endpoint);
  }

  @override
  Future<ResourceCollection> getRelated(
      String endpoint, String id, String relationshipName) async {
    final response = await httpGet("$apiPath/$endpoint/$id/$relationshipName");
    String payload = checkAndDecode(response) ?? '{}';
    return _deserializeMany(payload, endpoint);
  }

  ResourceCollection _deserializeMany(
    String payload,
    String endpoint,
  ) {
    return ResourceCollection(
        formatter.deserializeMany(payload) as ResourceCollection);
  }

  @override
  Future<ResourceObject> save(
    String endpoint,
    Object document,
  ) async {
    if (document is! ResourceObject) {
      throw ArgumentError('Document must be a ResourceObject');
    }
    ResourceObject? resource;
    try {
      resource = document;
      http.Response response;

      if (resource.isNew) {
        response = await httpPost("$apiPath/$endpoint",
            body: formatter.serialize(resource));
      } else {
        response = await httpPatch("$apiPath/$endpoint/${resource.id}",
            body: formatter.serialize(resource));
      }
      String payload = checkAndDecode(response) ?? '{}';

      ResourceObject saved = formatter.deserialize(payload) as ResourceObject;

      return saved;
    } on UnprocessableException catch (e) {
      Map parsed = (formatter as Serializer).parse(e.responseBody!);
      if (parsed.containsKey('errors')) {
        resource!.errors = parsed['errors'];
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
    Object related,
  ) async {
    if (related is! ResourceObject) {
      throw ArgumentError('Document must be a ResourceObject');
    }
    ResourceObject? resource;

    try {
      resource = related;
      http.Response response;

      response = await httpPatch("$apiPath/$endpoint/$id/$relationshipName",
          body: formatter.serialize(resource));

      String payload = checkAndDecode(response) ?? '{}';

      ResourceObject saved = formatter.deserialize(payload) as ResourceObject;

      return saved;
    } on UnprocessableException catch (e) {
      Map parsed = (formatter as Serializer).parse(e.responseBody!);

      if (parsed.containsKey('errors')) {
        throw InvalidRecordException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future delete(String endpoint, Object document) async {
    if (document is! ResourceObject) {
      throw ArgumentError('Document must be a ResourceObject');
    }
    ResourceObject? jsonApiDoc;
    try {
      jsonApiDoc = document;
      final response = await httpDelete("$apiPath/$endpoint/${jsonApiDoc.id}");
      checkAndDecode(response);

      return response;
    } on UnprocessableException catch (e) {
      Map parsed = (formatter as Serializer).parse(e.responseBody!);
      if (parsed.containsKey('errors')) {
        jsonApiDoc!.errors = parsed['errors'];
        throw InvalidRecordException();
      } else {
        rethrow;
      }
    }
  }
}
