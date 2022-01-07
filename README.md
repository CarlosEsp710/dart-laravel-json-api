# Laravel Json Api

This package was created to consume an API based on the [JSON:API](https://jsonapi.org/) spec made in Laravel with the help
of the [cloudcreativity/laravel-json-api](https://laravel-json-api.readthedocs.io/en/latest/) package.

## Features

- Schemas
- Custom headers (Accept, Content-Type, Authorization, etc)
- JSON:API Formatter
- Http requests (GET, POST, PATCH, DELETE, PUT)
- Filter resources
- Get related resources
- Get relationships
- Exception handling

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

Adapter adapter = ApiController('www.host.com', '/api/v1');
```

(No need to add http or https protocol)\
To use the adapter in our entire application we can wrap it in some state handler, we recommend using [provider](https://pub.dev/packages/provider).

## Headers

By default these are the values of the following headers:

| Header       | Value                    |
| ------------ | ------------------------ |
| Accept       | application/vnd.api+json |
| Content-Type | application/vnd.api+json |

But they can be overwritten.

```dart
import 'package:laravel_json_api/laravel_json_api.dart';

ApiController controller = ApiController('www.host.com', '/api/v1');
print(controller.headers);
controller.addHeader('Authorization', 'Beaer token');
controller.addHeader('Accept', 'application/json');
controller.addHeader('Content-Type', 'application/json');
print(controller.headers);

Adapter adapter = api;
```

## Create Schemas

Schemas provide getters and setters that help us transform responses into objects with their own attributes, relationships, related objects and errors.

For this example we will use a simple blog:

```dart
import 'package:laravel_json_api/laravel_json_api.dart';

class Article extends Schema {
  //Constructors
  Article(ResourceObject resourceObject) : super(resourceObject);
  Article.init(String type) : super.init(type);

  //Attributes

  String get title => getAttribute<String>('title');
  set title(String value) => setAttribute<String>('title', value);

  String get slug => getAttribute<String>('slug');
  set slug(String value) => setAttribute<String>('slug', value);

  String get content => getAttribute<String>('content');
  set content(String value) => setAttribute<String>('content', value);

  String get image => getAttribute<String>('image');
  set image(String value) => setAttribute<String>('image', value);

  //Relationships
  String? get authorId => idFor('user');
  set author(User model) => setHasOne('author', model);
  Object? get relatedAuthor => includedDoc('users', 'user');

  String? get categoryId => idFor('category');
  set category(Category model) => setHasOne('category', model);
  Object? get relatedCategory => includedDoc('categories', 'category');
}

class Category extends Schema {
  //Constructors
  Category(ResourceObject resourceObject) : super(resourceObject);
  Category.init(String type) : super.init(type);

  //Attributes

  String get name => getAttribute<String>('name');
  set name(String value) => setAttribute<String>('name', value);

  String get slug => getAttribute<String>('slug');
  set slug(String value) => setAttribute<String>('slug', value);

  String get image => getAttribute<String>('image_cover');
  set image(String value) => setAttribute<String>('image_cover', value);

  //Relationships
  Iterable<String> get articlesId => idsFor('articles');
  Iterable<Object> get articles => includedDocs('articles');
}

class User extends Schema {
  //Constructors
  User(ResourceObject resourceObject) : super(resourceObject);
  User.init(String type) : super.init(type);

  //Attributes

  String get firstName => getAttribute<String>('first_name');
  set firstName(String value) => setAttribute<String>('first_name', value);

  String get email => getAttribute<String>('email');
  set email(String value) => setAttribute<String>('email', value);

  //Relationships
  Iterable<String> get articlesId => idsFor('articles');
  Iterable<Object> get articles => includedDocs('articles');
}

```

### All schema methods

- `String? idFor(String relationshipName)`
- `String? typeFor(String relationshipName)`
- `Map<String, dynamic> dataForHasOne(String relationshipName)`
- `Iterable<dynamic>? dataForHasMany(String relationshipName)`
- `Iterable<String> idsFor(String relationshipName)`
- `Iterable<ResourceObject> includedDocs(String type,[Iterable<String>? ids])`
- `ResourceObject? includedDoc(String type, String relationshipName)`
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
        Article(await adapter.find('articles', id) as ResourceObject);

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
        queryParams: {'include': 'category,user'}) as ResourceObject);

    return article;
  }
```

`GET | https://www.host.com/api/v1/articles/1?include=category,user`

#### Find All

```dart
Future<Iterable<Article>> getAllArticles() async {
    Iterable<Article> articles = (await adapter.findAll('articles'))
        .map<Article>((article) => Article(article as ResourceObject))
        .toList();

    return articles;
  }
```

`GET | https://www.host.com/api/v1/articles`

### More getting requests

- `Future<Iterable<Object>> findManyById(String endpoint, Iterable<String> ids, {Map<String, String> queryParams})`
- `Future<Iterable<Object>> getRelated(String endpoint, String id, String relationshipName)`
- `Future<Iterable<Object>> filter(String endpoint, String filterField, Iterable<String> values, {Map<String, String> queryParams})`

## Writing data

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
Article article = Article(await adapter.find('articles', '1') as ResourceObject);
article.title = 'Title Update';

await adapter.save('articles', article.jsonApiDoc);
```

Replace relationship

```dart
Article article = Article(await adapter.find('articles', '1') as ResourceObject);
Category newCategory = Category(await adapter.find('categories', '2') as ResourceObject);

await adapter.replaceRelationship('articles', 'category', article, newCategory);
```

Delete resource

```dart
Article article = Article(await adapter.find('articles', '1') as ResourceObject);

await adapter.delete('articles', article);
```
