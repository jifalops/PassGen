import 'package:crypto/crypto.dart';
import 'package:cipher/cipher.dart';
import 'package:cipher/block/aes_fast.dart';
import 'dart:typed_data';
import 'dart:convert';

class PassGen {
  static const String
    ALNUM  = "abcdefghijklmopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789",
    CHARS  = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()`-=[];',./~_+{}|:\"<>?",
    _PEPPER = "r>b0!y@`+^dT6llD%X|9_o_GJ2}@lfnd/C68Cm0PGl~rvRX[Jr*Nji<2nXhwSeUEkd3&/.#V/^o6pC{DlxFni<'0J(7G4pJ_Jc%9U1h9PSnwYo7ZaRM[Wr*Mq#u%)br",
    _CRYPTO = "Q%3NLoEHM6ZxKOXz>@o]f8t;+=17@h?#";

  PassGen() {
    
  }
  
  String cipher(String text, bool encrypt, [String key = _CRYPTO]) {    
    var bytes = encrypt
        ? _encode(text)
        : new Uint8List.fromList(CryptoUtils.base64StringToBytes(text));  
    var cipher = new AESFastEngine()
      ..init(encrypt, new KeyParameter(new Uint8List.fromList(UTF8.encode(key))));    
    var cipherText;    
    var list = new List();
    int offset = 0;
    while (offset < bytes.length) {
      cipherText = new Uint8List(cipher.blockSize);
      cipher.processBlock(bytes, offset, cipherText, 0);
      list.addAll(cipherText);
      offset += cipher.blockSize;
    }
    String result = encrypt 
        ? CryptoUtils.bytesToBase64(list)
        : _decode(new Uint8List.fromList(list));
    //print ('cipher:\n'+text+'\n'+result);
    return result;
  }

  Uint8List _encode(String text) {
    var len = text.length;
    int i = 0;
    while ((text.length+1) % 16 > 0) {
      text += text[i];
      i = (i + 1) % len;
    }   
    var encoded = new List<int>.from([len])..addAll(UTF8.encode(text));
    //print('encode(): length = ' + encoded.length.toString());
    return new Uint8List.fromList(encoded);
  }
  
  String _decode(Uint8List bytes) {
    int len = bytes.first;
    //print('decode len: ' + len.toString() + ' (out of ' + bytes.length.toString() + ')');
    return UTF8.decode(bytes.getRange(1, len + 1).toList());
  }
  
  List<int> hash(String text, [String pepper = _PEPPER]) {
    SHA256 hash = new SHA256();
    hash.add(UTF8.encode(pepper));
    hash.add(UTF8.encode(text));
    hash.add(UTF8.encode(pepper));
    return hash.close();
  }
  
  String convertHash(List<int> hash, int len, List<String> chars) {
    final int hashLen = hash.length;
    final int charsLen = chars.length;
    
    // Reduce hash to the given length with 
    // values refering to indices of the char list.
    List<int> indexes = new List<int>(len);
    int value;
    for (int i=0; i<len; ++i) {
      value = 0;
      for (int j=0; j<hashLen-i; j+=len) {
        value += hash[i + j];
      }
      indexes[i] = value % charsLen;
    }
    
    // Convert the new hash to a string
    List<String> result = new List<String>(len);
    for (int i=0; i<len; ++i) {
      result[i] = chars[indexes[i]];
    }
    return result.join();
  }
 

  String hashAndConvert(String text, int len, List<String> chars, [String salt = _PEPPER]) {
    return convertHash(hash(text, salt), len, chars);
  }
}