import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:redux/redux.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import 'package:syphon/context/types.dart';
import 'package:syphon/global/libs/storage/key-storage.dart';
import 'package:syphon/global/print.dart';
import 'package:syphon/global/values.dart';
import 'package:syphon/storage/constants.dart';
import 'package:syphon/storage/drift/database.dart';
import 'package:syphon/storage/sembast/codec.dart';
import 'package:syphon/store/auth/storage.dart';
import 'package:syphon/store/crypto/storage.dart';
import 'package:syphon/store/events/messages/actions.dart';
import 'package:syphon/store/events/messages/model.dart';
import 'package:syphon/store/events/messages/storage.dart';
import 'package:syphon/store/events/reactions/actions.dart';
import 'package:syphon/store/events/reactions/model.dart';
import 'package:syphon/store/events/reactions/storage.dart';
import 'package:syphon/store/events/receipts/actions.dart';
import 'package:syphon/store/events/receipts/model.dart';
import 'package:syphon/store/events/receipts/storage.dart';
import 'package:syphon/store/index.dart';
import 'package:syphon/store/media/actions.dart';
import 'package:syphon/store/media/storage.dart';
import 'package:syphon/store/rooms/room/model.dart';
import 'package:syphon/store/rooms/storage.dart';
import 'package:syphon/store/settings/storage.dart';
import 'package:syphon/store/user/storage.dart';

class Storage {
  // cache key identifiers
  static const keyLocation = '${Values.appLabel}@storageKey';

  // storage identifiers
  static const databaseLocation = '${Values.appLabel}-main-storage.db';

  // storage identifiers
  static const sqliteLocation = '${Values.appLabel}-cold-storage.db';

  // cold storage references
  static Database? instance;
  static StorageDatabase? database;
}

Future<StorageDatabase> initColdStorage({String? context = AppContext.DEFAULT}) async {
  final StorageDatabase database = await Future.value(StorageDatabase(context!)); // never null ^
  Storage.database = database;
  return database;
}

Future closeColdStorage(StorageDatabase? storage) async {
  if (storage != null) {
    storage.close();
  }
}

Future deleteColdStorage({String? context = AppContext.DEFAULT}) async {
  try {
    var storageLocation = Storage.sqliteLocation;

    if (context!.isNotEmpty) {
      storageLocation = '$context-$storageLocation';
    }

    storageLocation = DEBUG_MODE ? 'debug-$storageLocation' : storageLocation;

    final appDir = await getApplicationSupportDirectory();
    final file = File(path.join(appDir.path, storageLocation));
    await file.delete();
  } catch (error) {
    printError('[deleteColdStorage] ${error.toString()}');
  }
}

Future<Database?> initStorage({String? context = AppContext.DEFAULT}) async {
  try {
    var storageKeyId = Storage.keyLocation;
    var storageLocation = Storage.databaseLocation;

    if (context!.isNotEmpty) {
      storageKeyId = '$context-$storageKeyId';
      storageLocation = '$context-$storageLocation';
    }

    storageLocation = DEBUG_MODE ? 'debug-$storageLocation' : storageLocation;

    const version = 2;
    var storageFactory;

    // Configure cache encryption/decryption instance
    final storageKey = await loadKey(storageKeyId);

    if (Platform.isAndroid || Platform.isIOS) {
      // always open cold storage as sqflite
      storageFactory = getDatabaseFactorySqflite(
        sqflite.databaseFactory,
      );
    }

    /// Supports Windows/Linux/MacOS for now.
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      storageFactory = getDatabaseFactorySqflite(
        sqflite_ffi.databaseFactoryFfi,
      );
    }

    if (storageFactory == null) {
      throw UnsupportedError(
        'Sorry, Syphon does not support your platform yet. Hope to do so soon!',
      );
    }

    printInfo('[initStorage] $storageLocation $storageKey');

    final codec = getEncryptSembastCodec(password: storageKey);

    final openedDatabase = await storageFactory.openDatabase(
      storageLocation,
      codec: codec,
      version: version,
    );

    Storage.instance = openedDatabase;
    return openedDatabase;
  } catch (error) {
    printError('[initStorage] $error');
    return null;
  }
}

// Closes and saves storage
closeStorage(Database? database) async {
  if (database != null) {
    database.close();
  }
}

deleteStorage({String? context = AppContext.DEFAULT}) async {
  try {
    var storageKeyId = Storage.keyLocation;
    var storageLocation = Storage.databaseLocation;

    if (context!.isNotEmpty) {
      storageKeyId = '$context-$storageKeyId';
      storageLocation = '$context-$storageLocation';
    }

    storageLocation = DEBUG_MODE ? 'debug-$storageLocation' : storageLocation;

    late DatabaseFactory storageFactory;

    if (Platform.isAndroid || Platform.isIOS) {
      storageFactory = getDatabaseFactorySqflite(
        sqflite.databaseFactory,
      );
    }

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      storageFactory = getDatabaseFactorySqflite(
        sqflite_ffi.databaseFactoryFfi,
      );
    }

    await storageFactory.deleteDatabase(storageLocation);
    await deleteKey(storageKeyId);
  } catch (error) {
    printError('[deleteStorage] ${error.toString()}');
  }
}

///
/// Load Storage
///
/// bulk loads cold storage objects to RAM, this can
/// be much more specific and performant
///
/// for example, only load users that are known to be
/// involved in stored messages/events
///
/// TODO: convert auth, crypto, settings to new storage paradigm
///
Future<Map<String, dynamic>> loadStorage(Database storageOld, StorageDatabase storage) async {
  try {
    final userIds = <String>[];
    final messages = <String, List<Message>>{};
    final decrypted = <String, List<Message>>{};
    final reactions = <String, List<Reaction>>{};

    final auth = await loadAuth(storage: storageOld);
    final crypto = await loadCrypto(storage: storageOld);
    final settings = await loadSettings(storage: storageOld);

    final rooms = await loadRooms(storage: storage);

    for (final Room room in rooms.values) {
      messages[room.id] = await loadMessagesRoom(
        room.id,
        storage: storage,
      );

      decrypted[room.id] = await loadDecryptedRoom(
        room.id,
        storage: storage,
      );

      final currentUserIds =
          (messages[room.id] ?? []).map((message) => message.sender ?? '').toList();

      userIds.addAll(currentUserIds);
    }

    final users = await loadUsers(storage: storage, ids: userIds);

    final media = await loadMediaRelative(
      storage: storage,
      users: users.values.toList(),
      rooms: rooms.values.toList(),
    );

    return {
      StorageKeys.AUTH: auth,
      StorageKeys.USERS: users,
      StorageKeys.ROOMS: rooms,
      StorageKeys.MEDIA: media,
      StorageKeys.CRYPTO: crypto,
      StorageKeys.MESSAGES: messages,
      StorageKeys.REACTIONS: reactions,
      StorageKeys.DECRYPTED: decrypted,
      StorageKeys.SETTINGS: settings,
    };
  } catch (error) {
    printError('[loadStorage]  ${error.toString()}');
    return {};
  }
}

//
// Load Storage (Async)
//
// finishes loading cold storage objects to RAM, this can
// be much more specific and performant
//
// TODO: convert receipts to new storage
//
loadStorageAsync(StorageDatabase storage, Store<AppState> store) async {
  try {
    final rooms = store.state.roomStore.roomList;
    final messages = store.state.eventStore.messages;
    final decrypted = store.state.eventStore.messagesDecrypted;

    final medias = <String, Uint8List>{};
    final reactions = <String, List<Reaction>>{};
    final receipts = <String, Map<String, Receipt>>{};

    for (final Room room in rooms) {
      final currentMessages = messages[room.id] ?? [];
      final currentMessagesIds = currentMessages.map((e) => e.id ?? '').toList();

      reactions.addAll(await loadReactionsMapped(
        roomId: room.id,
        eventIds: currentMessagesIds,
        storage: storage,
      ));

      receipts[room.id] = await loadReceipts(
        currentMessagesIds,
        storage: storage,
      );

      medias.addAll(await loadMediaRelative(
        messages:
            messages.values.expand((e) => e).toList() + decrypted.values.expand((e) => e).toList(),
        storage: storage,
      ));
    }

    loadAsync() async {
      await Future.wait([
        store.dispatch(LoadMedia(mediaMap: medias)),
        store.dispatch(LoadReceipts(receiptsMap: receipts)),
        store.dispatch(LoadReactions(reactionsMap: reactions)),
      ] as Iterable<Future<dynamic>>);

      // mutate messages
      await store.dispatch(mutateMessagesAll());
    }

    loadAsync();
  } catch (error) {
    printError('[loadStorageAsync]  ${error.toString()}');
  }
}
