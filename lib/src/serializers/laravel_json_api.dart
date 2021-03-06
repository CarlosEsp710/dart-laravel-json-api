import 'dart:convert';

import '../exceptions.dart';
import '../interfaces.dart';

class Serializer implements Formatter {
  @override
  ResourceObject deserialize(String payload) {
    try {
      Map<String, dynamic> parsed = parse(payload);
      var data = parsed['data'] ?? {};
      return ResourceObject(data['id'], data['type'], data['attributes'],
          data['relationships'], parsed['included']);
    } on FormatException {
      throw DeserializationException();
    }
  }

  @override
  ResourceCollection deserializeMany(String payload) {
    Map<String, dynamic> parsed = parse(payload);
    var collection = (parsed['data'] as Iterable).map(
      (item) => ResourceObject(
        item['id'],
        item['type'],
        item['attributes'],
        item['relationships'],
        parsed['included'],
      ),
    );
    return ResourceCollection(collection, parsed['included'], parsed['meta']);
  }

  @override
  String serialize(Object document, {bool withIncluded = false}) {
    try {
      ResourceObject resource = (document as ResourceObject);
      Map<String, dynamic> jsonMap = {
        'data': {
          'type': resource.type,
          'attributes': resource.attributes,
          'relationships': resource.relationships,
        },
      };
      if (withIncluded) {
        jsonMap['included'] = resource.included;
      }
      if (resource.id != null) {
        jsonMap['data']['id'] = resource.id;
      }
      return json.encode(jsonMap);
    } on TypeError {
      throw ArgumentError('Document must be a ResourceObject');
    } on JsonUnsupportedObjectError {
      throw SerializationException();
    }
  }

  dynamic parse(String raw) => json.decode(raw);
}

class ResourceObject {
  String? id;
  String? type;
  Map<String, dynamic> attributes;
  Map<String, dynamic> relationships;
  Iterable<dynamic> included;
  List<dynamic> errors;

  ResourceObject(
      this.id, this.type, this.attributes, Map<String, dynamic>? relationships,
      [Iterable<dynamic>? included])
      : errors = [],
        relationships = relationships ?? {},
        included = included ?? [];

  ResourceObject.create(
    this.type,
    this.attributes, [
    Map<String, dynamic>? relationships,
  ])  : errors = [],
        included = [],
        relationships = relationships ?? {};

  ResourceObject.from(ResourceObject other)
      : this(
          other.id,
          other.type,
          Map<String, dynamic>.from(other.attributes),
          _deepCopyRelationships(other.relationships),
          other.included,
        );

  static _deepCopyRelationships(other) {
    dynamic firstValue;
    if (other is Map) {
      if (other.isEmpty) {
        return <String, dynamic>{};
      }
      firstValue = other.values.first;
      if (firstValue is! Map && firstValue is! List) {
        return Map<String, dynamic>.from(other);
      } else {
        return Map<String, dynamic>.fromIterables(
          other.keys as Iterable<String>,
          other.values.map((val) => _deepCopyRelationships(val)),
        );
      }
    }
    if (other is List) {
      if (other.isEmpty) {
        return <Map<String, dynamic>>[];
      }
      firstValue = other.first;
      if (firstValue is! Map && firstValue is! List) {
        return List<Map<String, dynamic>>.from(other);
      } else {
        return List<Map<String, dynamic>>.from(
            other.map((val) => _deepCopyRelationships(val)));
      }
    }
  }

  String get endpoint => (type ?? '').replaceAll(RegExp('_'), '-');

  bool get isNew => id == null;

  T getAttribute<T>(String key) {
    final rawAttribute = attributes[key];

    switch (T.toString()) {
      case 'bool':
        return rawAttribute ?? false;
      case 'String':
        return rawAttribute ?? '';
      case 'int':
        return rawAttribute ?? 0;
      case 'double':
        return rawAttribute ?? 0.0;
      case 'List<bool>':
        return rawAttribute == null
            ? List<bool>.empty() as T
            : (rawAttribute as List).cast<bool>() as T;
      case 'List<String>':
        return rawAttribute == null
            ? List<String>.empty() as T
            : (rawAttribute as List).cast<String>() as T;
      case 'List<int>':
        return rawAttribute == null
            ? List<int>.empty() as T
            : (rawAttribute as List).cast<int>() as T;
      case 'List<double>':
        return rawAttribute == null
            ? List<double>.empty() as T
            : (rawAttribute as List).cast<double>() as T;
    }

    return rawAttribute;
  }

  void setAttribute<T>(String key, T value) {
    dynamic rawValue;
    switch (T) {
      case String:
        rawValue = value == '' ? null : value;
        break;
      default:
        rawValue = value;
    }
    attributes[key] = rawValue;
  }

  String? idFor(String relationshipName) =>
      dataForHasOne(relationshipName)['id'];

  String? typeFor(String relationshipName) =>
      dataForHasOne(relationshipName)['type'];

  Iterable<String> idsFor(String relationshipName) =>
      relationships.containsKey(relationshipName)
          ? dataForHasMany(relationshipName).map((record) => record['id'])
          : <String>[];

  Map<String, dynamic> dataForHasOne(String relationshipName) =>
      relationships.containsKey(relationshipName)
          ? (relationships[relationshipName]['data'] ?? <String, dynamic>{})
          : <String, dynamic>{};

  Iterable<dynamic> dataForHasMany(String relationshipName) =>
      relationships[relationshipName]['data'] ?? [];

  void setHasOne(String relationshipName, String modelId, String modelType) {
    Map<String, dynamic> relationshipMap = {'id': modelId, 'type': modelType};
    if (relationships.containsKey(relationshipName)) {
      if (relationships[relationshipName]['data'] == null) {
        relationships[relationshipName]['data'] = relationshipMap;
      } else {
        relationships[relationshipName]['data']['id'] = modelId;
      }
    } else {
      relationships[relationshipName] = {'data': relationshipMap};
    }
  }

  void clearHasOne(String relationshipName) {
    if (relationships.containsKey(relationshipName)) {
      relationships[relationshipName]['data'] = null;
    } else {
      relationships[relationshipName] = {'data': null};
    }
  }

  ResourceObject? includedResource(String type, String relationshipName) {
    var id = idFor(relationshipName);
    var it = included
        .where((record) => record['type'] == type && record['id'] == id)
        .map<ResourceObject>(
          (record) => ResourceObject(
            record['id'],
            record['type'],
            record['attributes'],
            record['relationships'],
          ),
        );

    return it.isNotEmpty ? it.first : null;
  }

  Iterable<ResourceObject> includedResorces(String type,
      [Iterable<String>? ids]) {
    ids ??= idsFor(type);
    return included
        .where(
            (record) => record['type'] == type && ids!.contains(record['id']))
        .map<ResourceObject>(
          (record) => ResourceObject(
            record['id'],
            record['type'],
            record['attributes'],
            record['relationships'],
          ),
        );
  }

  bool get hasErrors => errors.isNotEmpty;

  bool attributeHasErrors(String attributeName) => hasErrors
      ? errors.any((error) =>
          _isAttributeError(error, attributeName) && _hasErrorDetail(error))
      : false;

  Iterable<String> errorsFor(String attributeName) => errors
      .where((error) => _isAttributeError(error, attributeName))
      .map((error) => error['detail']);

  void clearErrorsFor(String attributeName) {
    errors = errors
        .where((error) => !_isAttributeError(error, attributeName))
        .toList();
  }

  void clearErrors() {
    errors = [];
  }

  void addErrorFor(String attributeName, String errorMessage) {
    errors.add({
      'source': {'pointer': "/data/attributes/$attributeName"},
      'detail': errorMessage,
    });
  }

  bool _isAttributeError(Map<String, dynamic> error, String attributeName) =>
      error['source']['pointer'] == "/data/attributes/$attributeName";

  bool _hasErrorDetail(Map<String, dynamic> error) =>
      error['detail'] != null &&
      error['detail'] is String &&
      (error['detail'] as String).isNotEmpty;
}

typedef FilterFunction = bool Function(ResourceObject);

class ResourceCollection extends Iterable<ResourceObject> {
  Iterable<ResourceObject> docs;
  Iterable<dynamic> included;
  Map<String, dynamic> meta;
  Map<String, dynamic> links;

  ResourceCollection(
    this.docs, [
    Iterable<dynamic>? included,
    Map<String, dynamic>? meta,
    Map<String, dynamic>? links,
  ])  : meta = meta ?? <String, dynamic>{},
        links = links ?? <String, dynamic>{},
        included = included ?? [];

  @override
  Iterator<ResourceObject> get iterator => docs.iterator;

  void append(Iterable<ResourceObject> moreDocs) {
    docs = docs.followedBy(moreDocs);
  }

  void filter(FilterFunction filterFn) {
    docs = docs.where(filterFn);
  }

  Iterable<String> idsForHasOne(String relationshipName) => docs
      .map((doc) => doc.idFor(relationshipName))
      .whereType<String>()
      .toSet();

  Iterable<String> idsForHasMany(String relationshipName) => docs
      .map((doc) => doc.idsFor(relationshipName))
      .expand((ids) => ids)
      .toSet();

  Iterable<ResourceObject> includedDocs(String type) => included
      .where((record) => record['type'] == type)
      .map((record) => ResourceObject(record['id'], record['type'],
          record['attributes'], record['relationships']));
}
