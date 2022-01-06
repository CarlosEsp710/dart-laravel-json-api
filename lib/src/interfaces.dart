abstract class Serializer {
  String serialize(Object document);
  Object deserialize(String payload);
  Iterable<Object> deserializeMany(String payload);
}

abstract class Adapter {
  Serializer serializer;

  Adapter(this.serializer);

  Future<Object> find(String endpoint, String id,
      {Map<String, String> queryParams});

  Future<Iterable<Object>> findManyById(String endpoint, Iterable<String> ids,
      {Map<String, String> queryParams});

  Future<Iterable<Object>> findAll(String endpoint,
      {Map<String, String> queryParams});

  Future<Iterable<Object>> getRelated(
      String endpoint, String id, String relationshipName);

  Future<Iterable<Object>> filter(
      String endpoint, String filterField, Iterable<String> values);

  Future<Object> save(String endpoint, Object document);

  Future<Object> replaceRelationship(String endpoint, String relationshipName,
      String id, Object relatedDocument);

  Future delete(String endpoint, Object document);

  Future<Object> memberPutAction(
      String endpoint, Object document, String actionPath);
}

abstract class Schema {
  String? get id;
  String? get type;
  String serialize();
  T getAttribute<T>(String key);
  void setAttribute<T>(String key, T value);
}
