import 'dart:html';
import 'package:crypto/crypto.dart';
import 'package:cipher/cipher.dart';
import 'dart:typed_data';
import 'package:lawndart/lawndart.dart';
import 'dart:convert';
import 'package:chrome/chrome_ext.dart' as chrome;
//import 'dart:js';

void main() {
  var pg = new PassGen();
  
}

class PassGen {
  static const int 
      MIN_PASS_LEN = 4,
      MAX_PASS_LEN = 32,
      MIN_SITE_LEN = 4,
      MAX_SITE_LEN = 64,
      MIN_SECRET_LEN = 4,
      MAX_SECRET_LEN = 64;
  
  static const String 
    _KEY      = "r>b0!y@`+^dT6llD%X|9_o_GJ2}@lfnd/C68Cm0PGl~rvRX[Jr*Nji<2nXhwSeUEkd3&/.#V/^o6pC{DlxFni<'0J(7G4pJ_Jc%9U1h9PSnwYo7ZaRM[Wr*Mq#u%)br",
    _ALNUM    = "abcdefghijklmopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789",
    _CHARS    = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()`-=[];',./~_+{}|:\"<>?";
  
  final DivElement           _container  = querySelector('#PassGen');  
  final FormElement          _form       = querySelector('#form');
  final DivElement           _error      = querySelector('#info');
  final CheckboxInputElement _symbols    = querySelector('#symbols');
  final Element              _result     = querySelector('#result');
  final TextInputElement     _site       = querySelector('#site');
  final TextInputElement     _secret     = querySelector('#secret');
  final CheckboxInputElement _saveSecret = querySelector('#saveSecret');
  final SelectElement        _passLength = querySelector('#passLen');
  
  final Store _options = new Store('passgen', 'options');
  final String _passLenKey = 'passLen';
  final String _useSymbolsKey = 'useSymbols';
  final String _secretKey = 'secretKey';
  final String _saveSecretKey = 'saveSecretKey';

  int _passLen = 16;
  
  PassGen() {
    _error.hidden = true;
    _result.hidden = true;
    
    _options.open()
      .then((_) => _options.getByKey(_passLenKey))
      .then((value) => _passLen = int.parse(value))
      .then((_) => _addLengthOptions())
      .then((_) => _options.getByKey(_useSymbolsKey))
      .then((value) => _symbols.checked = value == true.toString())
      .then((_) => _options.getByKey(_saveSecretKey))
      .then((value) {
        _saveSecret.checked = value == true.toString();
        if (value == true.toString() && _options.isOpen) {
          _options.getByKey(_secretKey)
            .then((value) => _secret.value = value);
        }
      });
    
    
    //print(_passLen);
    //print(_symbols.checked);
    
    _prefillWebsite();
    //_addLengthOptions();
    
    _form.onSubmit.listen(generatePass);
    _secret.focus();
  }
  
  String _makeSecret() {
    String secret = _secret.value;
    
    // Not saving the last two characters!
    secret = secret.substring(0, secret.length - 2);
    
    var bytes = new Uint8List.fromList(UTF8.encode(secret));
    var key = new Uint8List.fromList(UTF8.encode(_KEY));
    var cipher = new BlockCipher("AES")  
      ..init(true, new KeyParameter(key));
    var cipherText = new Uint8List(cipher.blockSize);
    cipher.processBlock(bytes, 0, cipherText, 0);
    return UTF8.decode(cipherText.toList());
  }
 
  
  void _prefillWebsite() {
    try {
      var params = new chrome.TabsQueryParams()
        ..active = true
        ..currentWindow = true;
      chrome.tabs.query(params).then((tabs) {
        if (tabs.length != 1) {
          _error.text = "Found " + tabs.length.toString()
            + "active tabs (expected 1).";
        }
        _site.value = Uri.parse(tabs[0].url).host;
        print("x" +_site.value);
      });
    } catch(e) {
      _error.text = "Unable to get current website.";
      _error.hidden = false;
    }
  }
  
  void _addLengthOptions() {
    String s;
    for (int i=MIN_PASS_LEN; i<=MAX_PASS_LEN; ++i) {
      s = i.toString();
      _passLength.children.add(
          new OptionElement()
          ..value=s
          ..text=s
          ..selected=(i==_passLen));
    }
  }
  
  //TODO allow multiple errors on different lines
  void checkInputs() {
    _error.text = '';
    
    if (_site.value.length < MIN_SITE_LEN /*|| !site.contains('\.')*/) {
      _error.text = "Website too short.";
    } else if (_site.value.length > MAX_SITE_LEN) {
      _error.text = "Website too long."; 
    }
    
    if (_secret.value.length < MIN_SECRET_LEN) {
      _error.text = "Secret too short.";
    } else if (_secret.value.length > MAX_SECRET_LEN) {
      _error.text = "Secret too long."; 
    }
    
    if (int.parse(_passLength.value) < MIN_PASS_LEN) {
      _error.text = "Length too short.";
    } else if (_secret.value.length > MAX_SECRET_LEN) {
      _error.text = "Length too long."; 
    }
  }
  
  void generatePass(Event e) {
    e.preventDefault();
    _error.hidden = true;
    _result.hidden = true;
    
    _options.open()
      .then((_) => _options.nuke())
      .then((_) => _options.save(_passLength.value, _passLenKey))
      .then((_) => _options.save(_saveSecret.checked.toString(), _saveSecretKey))
      .then((_) => _options.save(_symbols.checked.toString(), _useSymbolsKey)
      .then((_) {
        if (_saveSecret.checked && _options.isOpen) {
          _options.save(_makeSecret(), _secretKey);
        }
      }));
    
    checkInputs();
    if (_error.text.length > 0) {
      _error.hidden = false;
      return;
    }
    
    
    SHA256 hash = new SHA256(); 
    hash.add(UTF8.encode(_site.value));
    hash.add(UTF8.encode(_KEY));
    hash.add(UTF8.encode(_secret.value));
    _result.text = _hashToString(hash.close(), int.parse(_passLength.value)).join();
    
    if (_result.text.length > 0) {
      _result.hidden = false;
      window.getSelection().selectAllChildren(_result);
    }
  }
  
  List<String> _hashToString(List<int> hash, int len) {   
    List<String> chars = _symbols.checked ? _CHARS.split('') : _ALNUM.split('');    
    List<int> indexes = _reduceHash(hash, len,  chars.length);
    List<String> result = new List<String>(indexes.length);
    for (int i=0; i<indexes.length; ++i) {
      result[i] = chars[indexes[i]];
    }
    return result;
  }
  
  List<int> _reduceHash(List<int> hash, int len, int maxValue) {
    List<int> newHash = new List<int>(len);
    int value;
    for (int i=0; i<len; ++i) {
      value = 0;
      for (int j=0; j<hash.length-i; j+=len) {
        value += hash[i + j];
      }
      newHash[i] = value % maxValue;
    }
    return newHash;
  }
}

