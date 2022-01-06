# Laravel Json Api

Consume api rest services. Supports JSON:API-compliant REST APIs.
This package was created to consume an API made in Laravel with the help of the [cloudcreativity/laravel-json-api](https://laravel-json-api.readthedocs.io/en/latest/) package,
but it supports any REST service based on the [JSON:API](https://jsonapi.org/) spec.

## Features

- Custom models
- Custom headers (Accept, Content-Type, Authorization, etc)
- Serialization and deserialization
- Http requests (GET, POST, PATCH, DELETE, PUT)
- Filter resources
- Get related resources using relationships
- Get relationships
- Exception handling
- Simple cache

## Installation

Install in dart

```bash
  dart pub add laravel_json_api
```

Install in flutter

```bash
  flutter pub add laravel_json_api
```

## Usage

## Connecting with our server

```dart
import 'package:laravel_json_api/laravel_json_api.dart';

Adapter adapter = LaravelJsonApiAdapter('www.host.com', '/api/v1');
```

(No need to add http or https protocol)\
To use the adapter in our entire application we can wrap it in some state handler, we recommend using [provider](https://pub.dev/packages/provider).

## Add header

```dart
import 'package:laravel_json_api/laravel_json_api.dart';

LaravelJsonApiAdapter api = LaravelJsonApiAdapter('www.host.com', '/api/v1');
api.addHeader('Authorization', 'Bearer token');
Adapter adapter = api;
```

By default these are the values of the following headers:

- Accept -> application/vnd.api+json
- Content-Type -> application/vnd.api+json
  But they can be overwritten.

## Create models

Models provide getters and setters that help us transform responses into objects with their own attributes, relationships, included files and errors.

For this example we will use a simple blog:

```dart
import 'package:laravel_json_api/laravel_json_api.dart';

class Article extends LaravelJsonApiModel {
  //Constructors
  Article(LaravelJsonApiDocument jsonApiDoc) : super(jsonApiDoc);
  Article.init(String type) : super.init(type);

  //Attributes

  String get title => getAttribute<String>('title');
  set title(String value) => setAttribute<String>('title', value);

  String get content => getAttribute<String>('content');
  set content(String value) => setAttribute<String>('content', value);

  //Relationships
  String? get userId => idFor('user');
  set user(User model) => setHasOne('user', model);
  Object? get relatedUser => includedDoc('users', 'user');

  String? get categoryId => idFor('category');
  set category(Category model) => setHasOne('category', model);
  Object? get relatedCategory => includedDoc('categories', 'category');
}

class Category extends LaravelJsonApiModel {
  //Constructors
  Category(LaravelJsonApiDocument jsonApiDoc) : super(jsonApiDoc);
  Category.init(String type) : super.init(type);

  //Attributes

  String get name => getAttribute<String>('name');
  set name(String value) => setAttribute<String>('name', value);

  //Relationships
  Iterable<String> get articlesId => idsFor('articles');
  Iterable<Object> get articles => includedDocs('articles');
}

class User extends LaravelJsonApiModel {
  //Constructors
  User(LaravelJsonApiDocument jsonApiDoc) : super(jsonApiDoc);
  User.init(String type) : super.init(type);

  //Attributes

  String get name => getAttribute<String>('name');
  set name(String value) => setAttribute<String>('name', value);

  String get email => getAttribute<String>('email');
  set email(String value) => setAttribute<String>('email', value);

  //Relationships
  Iterable<String> get articlesId => idsFor('articles');
  Iterable<Object> get articles => includedDocs('articles');
}

```

### All getters and functions

- `String? idFor(String relationshipName)`
- `String? typeFor(String relationshipName)`
- `Map<String, dynamic> dataForHasOne(String relationshipName)`
- `Iterable<dynamic>? dataForHasMany(String relationshipName)`
- `Iterable<String> idsFor(String relationshipName)`
- `Iterable<LaravelJsonApiDocument> includedDocs(String type,[Iterable<String>? ids])`
- `LaravelJsonApiDocument? includedDoc(String type, String relationshipName)`
- `void clearErrorsFor(String attributeName)`
- `bool get hasErrors`
- `bool attributeHasErrors(String attributeName)`
- `Iterable<String> errorsFor(String attributeName)`
- `void clearErrors()`
- `void addErrorFor(String attributeName, String errorMessage)`
- `void setHasOne(String relationshipName, LaravelJsonApiModel model)`

## Getting data

All of these actions are asynchronous and return a specific value.

### Find One

```dart
Future<Article> getOneArticle(String id) async {
    Article article =
        Article(await adapter.find('articles', id) as LaravelJsonApiDocument);

    return article;
  }
```

`GET | https://www.host.com/api/v1/articles/1`

Optionally we can send the `forceReload` parameter to cache this resource,
and the `queryParam` to sort or include relationships.

```dart
Future<Article> getOneArticle(String id) async {
    Article article = Article(await adapter.find('articles', id,
        forceReload: true,
        queryParams: {'include': 'category,user'}) as LaravelJsonApiDocument);

    return article;
  }
```

`GET | https://www.host.com/api/v1/articles/1?include=category,user`

#### Find All

```dart
Future<Iterable<Article>> getAllArticles() async {
    Iterable<Article> articles = (await adapter.findAll('articles'))
        .map<Article>((article) => Article(article as LaravelJsonApiDocument))
        .toList();

    return articles;
  }
```

`GET | https://www.host.com/api/v1/articles`

### More getting requests

- `Future<Iterable<Object>> findManyById(String endpoint, Iterable<String> ids, {bool forceReload = false, Map<String, String> queryParams})`
- `Future<Iterable<Object>> getRelated(String endpoint, String id, String relationshipName)`
- `Future<Iterable<Object>> filter(String endpoint, String filterField, Iterable<String> values, {bool forceReload = false})`

## Writing data

With cached resource

```dart
Article article = Article.init('articles');
article.title = 'Title';
article.content = 'Content';
article.user = User(adapter.peek('users', '1') as LaravelJsonApiDocument);
article.category = Category(adapter.peek('users', '1') as LaravelJsonApiDocument);
```

Receiving a resource

```dart
Article article = Article.init('articles');
article.title = 'Title';
article.content = 'Content';
article.user = user;
article.category = category;
```

Create resource

```dart
Future saveArticle(Article article) async {
  await adapter.save('articles', article.jsonApiDoc);
}
```

Update resource

```dart
Article article = Article(await adapter.find('articles', '1') as LaravelJsonApiDocument);
article.title = 'Title Update';

await adapter.save('articles', article.jsonApiDoc);
```

Replace relationship

```dart
Article article = Article(await adapter.find('articles', '1') as LaravelJsonApiDocument);
Category newCategory = Category(await adapter.find('categories', '2') as LaravelJsonApiDocument);

await adapter.replaceRelationship('articles', 'category', article, newCategory);
```

Delete resource

```dart
Article article = Article(await adapter.find('articles', '1') as LaravelJsonApiDocument);

await adapter.delete('articles', article);
```
