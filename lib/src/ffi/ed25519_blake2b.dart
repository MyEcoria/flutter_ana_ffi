import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// Get if lib set in environment
final String libraryPath = Platform.environment.containsKey("ED215519_SO_FILE")
    ? Platform.environment["ED215519_SO_FILE"]
    : null;

// Load C library and functions
final DynamicLibrary dyLib = libraryPath != null
    ? DynamicLibrary.open(libraryPath)
    : Platform.isAndroid
        ? DynamicLibrary.open("libed25519_blake2b.so")
        : DynamicLibrary.process();

// C publickey function - void dart_publickey(unsigned char *sk, unsigned char *pk);
typedef publickey_func = Void Function(Pointer<Uint8> sk, Pointer<Uint8> pk);
typedef Publickey = void Function(Pointer<Uint8> sk, Pointer<Uint8> pk);
final void Function(Pointer<Uint8>, Pointer<Uint8>) pubkeyFunc = dyLib
    .lookup<NativeFunction<publickey_func>>('dart_publickey')
    .asFunction<Publickey>();

// C privatekey function - void dart_privatekey(unsigned char *sk, unsigned char *seed, int index);
typedef privatekey_func = Void Function(
    Pointer<Uint8> sk, Pointer<Uint8> seed, Uint32 index);
typedef Privatekey = void Function(
    Pointer<Uint8> sk, Pointer<Uint8> seed, int index);
final void Function(Pointer<Uint8>, Pointer<Uint8>, int) privkeyFunc = dyLib
    .lookup<NativeFunction<privatekey_func>>('dart_privatekey')
    .asFunction<Privatekey>();

// C signature function - void dart_sign(ed25519_signature sig, size_t mlen, unsigned char *m, unsigned char *randr, unsigned char *sk) {
typedef signature_func = Void Function(Pointer<Uint8> sig, Uint32 mlen,
    Pointer<Uint8> m, Pointer<Uint8> randr, Pointer<Uint8> sk);
typedef Signature = void Function(Pointer<Uint8> sig, int mlen,
    Pointer<Uint8> m, Pointer<Uint8> randr, Pointer<Uint8> sk);
final void Function(
        Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>)
    signFunc = dyLib
        .lookup<NativeFunction<signature_func>>('dart_sign')
        .asFunction<Signature>();

// C validate sig function - int dart_validate_sig(ed25519_signature sig, size_t mlen, unsigned char *m, ed25519_public_key pk) {
typedef verify_func = Int32 Function(
    Pointer<Uint8> sig, Uint32 mlen, Pointer<Uint8> m, Pointer<Uint8> pk);
typedef Verify = int Function(
    Pointer<Uint8> sig, int mlen, Pointer<Uint8> m, Pointer<Uint8> pk);
final int Function(Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Uint8>)
    verifyFunc = dyLib
        .lookup<NativeFunction<verify_func>>('dart_validate_sig')
        .asFunction<Verify>();

class Ed25519Blake2b {
  // Copy byte array to native heap
  static Pointer<Uint8> _bytesToPointer(Uint8List bytes) {
    final length = bytes.lengthInBytes;
    final result = allocate<Uint8>(count: length);

    for (var i = 0; i < length; ++i) {
      result[i] = bytes[i];
    }

    return result;
  }

  // Get public key from secret key
  static Uint8List getPubkey(Uint8List secretKey) {
    final pointer = _bytesToPointer(secretKey);
    final result = allocate<Uint8>(count: 32);
    pubkeyFunc(pointer, result);
    free(pointer);
    return result.asTypedList(32);
  }

  // Derive private key from seed at index
  static Uint8List derivePrivkey(Uint8List seed, int index) {
    final seedPointer = _bytesToPointer(seed);
    final result = allocate<Uint8>(count: 32);
    privkeyFunc(result, seedPointer, index);
    free(seedPointer);
    return result.asTypedList(32);
  }

  // Sign message with given private key
  static Uint8List signMessage(Uint8List m, Uint8List sk) {
    final mPointer = _bytesToPointer(m);
    final skPointer = _bytesToPointer(sk);
    final randPointer = _bytesToPointer(rand32());
    final result = allocate<Uint8>(count: 64);
    signFunc(result, m.lengthInBytes, mPointer, randPointer, skPointer);
    free(mPointer);
    free(skPointer);
    free(randPointer);
    return result.asTypedList(64);
  }

  // Verify signature with given message an public key, return true if valid
  static bool verifySignature(Uint8List m, Uint8List pk, Uint8List sig) {
    final mPointer = _bytesToPointer(m);
    final pkPointer = _bytesToPointer(pk);
    final sigPointer = _bytesToPointer(sig);
    bool valid =
        verifyFunc(sigPointer, m.lengthInBytes, mPointer, pkPointer) == 1;
    free(mPointer);
    free(pkPointer);
    free(sigPointer);
    return valid;
  }

  // Generate 32 random-bytes
  static Uint8List rand32() {
    Uint8List randBytes = Uint8List(32);
    Random rng = Random.secure();
    for (int i = 0; i < 32; i++) {
      randBytes[i] = rng.nextInt(127);
    }
    return randBytes;
  }
}
