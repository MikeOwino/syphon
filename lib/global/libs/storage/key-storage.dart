import 'package:encrypt/encrypt.dart';
import 'package:syphon/global/print.dart';
import 'package:syphon/global/libs/storage/secure-storage.dart';

String generateKey() {
  return Key.fromSecureRandom(32).base64;
}

Future<bool> checkKey(String keyId) async {
  try {
    return await SecureStorage.check(key: keyId);
  } catch (error) {
    printError('[checkKey] $error');
    return false;
  }
}

Future<String> loadKey(String keyId) async {
  String? key;

  // try to read key
  try {
    key = await SecureStorage().read(key: keyId);
  } catch (error) {
    printError('[loadKey] $error');
  }

  // generate a new one on failure
  if (key == null) {
    printInfo('[loadKey] generating new key for $keyId');
    key = generateKey();
    await SecureStorage().write(key: keyId, value: key);
  }

  return key;
}

Future deleteKey(String keyId) async {
  // try to read key
  try {
    await SecureStorage().delete(key: keyId);
  } catch (error) {
    printError('[deleteKey] $error');
  }
}
