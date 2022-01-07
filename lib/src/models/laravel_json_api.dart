import 'package:equatable/equatable.dart';

import '../exceptions.dart';
import '../interfaces.dart';
import '../serializers/laravel_json_api.dart';

class Schema with EquatableMixin implements Model {
  ResourceObject resourceObject;

  Schema(this.resourceObject);

  Schema.create(
    String type, {
    Map<String, dynamic>? attributes,
    Map<String, dynamic>? relationships,
  }) : resourceObject = ResourceObject.create(
          type,
          attributes ?? <String, dynamic>{},
          relationships ?? <String, dynamic>{},
        );

  Schema.init(String type) : this.create(type);

  Schema.from(Schema other) : this(ResourceObject.from(other.resourceObject));

  Schema.shallowCopy(Schema other) : this(other.resourceObject);

  String get endpoint => resourceObject.endpoint;
  Map<String, dynamic> get attributes => resourceObject.attributes;
  Map<String, dynamic> get relationships => resourceObject.relationships;
  Iterable<dynamic> get included => resourceObject.included;
  List<dynamic> get errors => resourceObject.errors;

  @override
  String? get id => resourceObject.id;

  @override
  String? get type => resourceObject.type;

  @override
  T getAttribute<T>(String key) => resourceObject.getAttribute<T>(key);

  @override
  void setAttribute<T>(String key, T value) =>
      resourceObject.setAttribute<T>(key, value);

  @override
  String serialize() => Serializer().serialize(resourceObject);

  @override
  List<Object?> get props => [id, type, errors];

  bool get isNew => resourceObject.isNew;

  bool get hasErrors => resourceObject.hasErrors;

  String? idFor(String relationshipName) =>
      resourceObject.idFor(relationshipName);

  String? typeFor(String relationshipName) =>
      resourceObject.typeFor(relationshipName);

  Map<String, dynamic> dataForHasOne(String relationshipName) =>
      resourceObject.dataForHasOne(relationshipName);

  Iterable<dynamic>? dataForHasMany(String relationshipName) =>
      resourceObject.dataForHasMany(relationshipName);

  Iterable<String> idsFor(String relationshipName) =>
      resourceObject.idsFor(relationshipName);

  ResourceObject? includedDoc(String type, String relationshipName) =>
      resourceObject.includedResource(type, relationshipName);

  Iterable<ResourceObject> includedDocs(String type, [Iterable<String>? ids]) =>
      resourceObject.includedResorces(type, ids);

  bool attributeHasErrors(String attributeName) =>
      resourceObject.attributeHasErrors(attributeName);

  Iterable<String> errorsFor(String attributeName) =>
      resourceObject.errorsFor(attributeName);

  void clearErrorsFor(String attributeName) {
    resourceObject.clearErrorsFor(attributeName);
  }

  void clearErrors() {
    resourceObject.clearErrors();
  }

  void addErrorFor(String attributeName, String errorMessage) {
    resourceObject.addErrorFor(attributeName, errorMessage);
  }

  void setHasOne(String relationshipName, Schema schema) {
    if (schema.type == null) {
      throw DataStructureException(
          'Cannot set schema with null type on has-one relationship');
    }
    if (schema.id == null) {
      throw DataStructureException(
          'Cannot set schema with null id on has-one relationship');
    }
    resourceObject.setHasOne(relationshipName, schema.id!, schema.type!);
  }

  void clearHasOne(String relationshipName) {
    resourceObject.clearHasOne(relationshipName);
  }

  static DateTime? toDateTime(String value) =>
      (value.isEmpty) ? null : DateTime.parse(value).toLocal();

  static String toUtcIsoString(DateTime value) =>
      value.toUtc().toIso8601String();
}

abstract class Schemas<T extends Schema> extends Iterable<T> {
  ResourceCollection manyDoc;
  late Iterable<T> schemas;

  Schemas(this.manyDoc);

  @override
  Iterator<T> get iterator => schemas.iterator;

  bool get hasMeta => manyDoc.meta.isNotEmpty;
  int? get currentPage => manyDoc.meta['page']['current-page'];
  int? get perPage => manyDoc.meta['page']['per-page'];
  int? get from => manyDoc.meta['page']['from'];
  int? get to => manyDoc.meta['page']['to'];
  int? get total => manyDoc.meta['page']['total'];
  int? get lastPage => manyDoc.meta['page']['last-page'];

  bool get hasLinks => manyDoc.links.isNotEmpty;

  Iterable<ResourceObject> includedDocs(String type) =>
      manyDoc.includedDocs(type);
}
