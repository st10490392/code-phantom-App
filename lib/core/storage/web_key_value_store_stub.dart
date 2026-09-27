import 'key_value_store.dart';

KeyValueStore createWebKeyValueStore() =>
    throw UnsupportedError('The browser key/value store is only available on the web.');
