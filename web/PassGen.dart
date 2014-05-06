import 'package:crypto/crypto.dart';
import 'package:cipher/cipher.dart';
import 'package:cipher/block/aes_fast.dart';
import 'dart:typed_data';
import 'dart:convert';

class PassGen {
  static const int
    CHAR_LOWER   = 0x1,
    CHAR_UPPER   = 0x2,
    CHAR_NUMBERS = 0x4,
    CHAR_SYMBOLS = 0x8,
    CHAR_LETTERS = 0x3,
    CHAR_ALNUM   = 0x7,
    CHAR_ALL     = 0xF;
    
  static const String
    _LOWER   = 'abcdefghijkmnopqrstuvwxyz',  // skip l
    _UPPER   = 'ABCDEFGHJKLMNOPQRSTUVWXYZ',  // skip I
    _NUMBERS = '0123456789',
    _SYMBOLS = r'!@#$%^&*()`-=[];,./~_+{}|:"<>?', // skip \' (backslash and apostrophe)

    _PEPPER = "r>b0!y@`+^dT6llD%X|9_o_GJ2}@lfnd/C68Cm0PGl~rvRX[Jr*Nji<2nXhwSeUEkd3&/.#V/^o6pC{DlxFni<'0J(7G4pJ_Jc%9U1h9PSnwYo7ZaRM[Wr*Mq#u%)br",
    _CRYPTO = "Q%3NLoEHM6ZxKOXz>@o]f8t;+=17@h?#";

  static final String
    _LETTERS = _LOWER + _UPPER,
    _ALNUM   = _LETTERS + _NUMBERS,
    _CHARS   = _ALNUM + _SYMBOLS;
  
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
  
  
  String convertHash(List<int> hash, int len, int charTypes) {
    int hashLen = hash.length;    
    var result = new StringBuffer();
    var chars = _getChars(charTypes);
    
    var pref = _getCharPrefs(charTypes);
    
    int value;
    var tmpChars;
    for (int i=0; i<len; ++i) {
      value = 0;
      for (int j=0; j<hashLen-i; j+=len) {
        value += hash[i + j];
      }
      
      if (i < pref.length && pref[i] > 0) {
        tmpChars = _getChars(pref[i]);
        result.write(tmpChars[value % tmpChars.length]);
      } else {
        result.write(chars[value % chars.length]);
      }      
    }
    
    return result.toString();
  }
  
  String hashAndConvert(String text, int len, int charTypes, [String salt = _PEPPER]) {
    return convertHash(hash(text, salt), len, charTypes);
  }
  
  String _getChars(int type) {
    String chars = '';
    if (type & CHAR_LOWER > 0) chars += _LOWER;
    if (type & CHAR_UPPER > 0) chars += _UPPER;
    if (type & CHAR_NUMBERS > 0) chars += _NUMBERS;
    if (type & CHAR_SYMBOLS > 0) chars += _SYMBOLS;
    return chars;
  }
  
  List<int> _getCharPrefs(int type) {
    var pref = [0];
    switch (type) {
      case CHAR_ALL:
        pref = [CHAR_LOWER, CHAR_NUMBERS, CHAR_UPPER, CHAR_SYMBOLS];
        break;
      case CHAR_ALNUM:
        pref = [CHAR_LOWER, CHAR_NUMBERS, CHAR_UPPER];
        break;
      case CHAR_LETTERS:
        pref = [CHAR_LOWER, CHAR_UPPER];    
        break;
        
      // Mixes of three types
      case CHAR_LETTERS | CHAR_SYMBOLS:
        pref = [CHAR_LOWER, CHAR_SYMBOLS, CHAR_UPPER];
        break;
      case CHAR_LOWER | CHAR_NUMBERS | CHAR_SYMBOLS:
        pref = [CHAR_LOWER, CHAR_NUMBERS, CHAR_SYMBOLS];
        break;
      case CHAR_UPPER | CHAR_NUMBERS | CHAR_SYMBOLS:
        pref = [CHAR_UPPER, CHAR_NUMBERS, CHAR_SYMBOLS];
        break;
        
      // Mixes of two types  
      case CHAR_LOWER | CHAR_NUMBERS:
        pref = [CHAR_LOWER, CHAR_NUMBERS];
        break;
      case CHAR_LOWER | CHAR_SYMBOLS:
        pref = [CHAR_LOWER, CHAR_SYMBOLS];
        break;
      case CHAR_UPPER | CHAR_NUMBERS:
        pref = [CHAR_UPPER, CHAR_NUMBERS];
        break;
      case CHAR_UPPER | CHAR_SYMBOLS:
        pref = [CHAR_UPPER, CHAR_SYMBOLS];
        break;
      case CHAR_NUMBERS | CHAR_SYMBOLS:
        pref = [CHAR_NUMBERS, CHAR_SYMBOLS];
        break;      
    }
print('prefs: ' + pref.toString());
    return pref;
  }
}