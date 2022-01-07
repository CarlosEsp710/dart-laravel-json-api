import 'package:laravel_json_api/laravel_json_api.dart';

// Main
void main() async {
  ApiController controller = ApiController('maeth.herokuapp.com', '/api/v1');

  controller.addHeader(
      'Authorization', 'Bearer 32|nEbOJRQUB4jSU9Zh2BcWLqKEpPWQ73hVPbKcZsFn');

  Adapter adapter = controller;

  // Get user
  User user = await _getUser(adapter);
  print(user);

  // Get categories
  Iterable<Category> categories = await _getCategories(adapter);
  print(categories.first);

  // Create article
  Article newArticle = Article.init('articles');
  newArticle.title = 'Test 1';
  newArticle.slug = 'title-1';
  newArticle.content = 'Content test 1';
  newArticle.image =
      'https://res.cloudinary.com/maeth/image/upload/v1638752850/articles/cbogi4o5mny0iggmt1j4.jpg';
  newArticle.author = user;
  newArticle.category = categories.first;

  var response = await _saveArticle(adapter, newArticle.resourceObject);

  if (response == true) {
    print('Article created');
  } else {
    print('Article not created');
    print(response);
  }

  print(user.articles);
}

Future<User> _getUser(Adapter adapter) async {
  return User(await adapter.find(
      'users', '3c85faf7-eacb-4b6b-8547-4e5bd2b24c3f',
      queryParams: {'include': 'articles'}) as ResourceObject);
}

Future<Iterable<Category>> _getCategories(Adapter adapter) async {
  return (await adapter.findAll('categories'))
      .map<Category>((category) => Category(category as ResourceObject))
      .toList();
}

Future _saveArticle(Adapter adapter, Object model) async {
  try {
    Article(await adapter.save('articles', model) as ResourceObject);
    return true;
  } catch (e) {
    print(e);
    Article temp = Article(model as ResourceObject);
    return temp.errors.first['detail'];
  }
}

// models

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
