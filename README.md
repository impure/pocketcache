<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

An wrapper around PocketBase allowing for easy offline use. Designed for my RSS reader Stratum ([iOS](https://apps.apple.com/us/app/stratum-rss-feed-reader/id6445805598), [Android](https://play.google.com/store/apps/details?id=com.amorfatite.keystone)).

## Features

- List files offline
- Refresh Auth token without errors

## Getting started

This package uses `sqlite3`. It should work on all platforms except for web without additional configuration.

Note that this package reserves the following:

- Column names starting in `_offline_bool_`
- The column name `_downloaded`

In addition it expects all of PocketBases data to have the `id`, `created`, and `updated` fields.

## Usage

Init the package:

```dart
initPbOffline(pb);
```

Then you can use any of the exposed wrappers.

```dart
resetAuth();

List<Map<String, dynamic>> data = getListWrapper("some_collection", page: 1, page_count: 1));
```

## Additional information

Be careful about updating columns with uniqueness constraints or adding rows with uniqueness constraints. Database rules are not enforced on the client and these operations may fail when sent to the server.
