import 'dart:html';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:chrome/chrome_ext.dart' as chrome;
//import 'dart:js';

void main() {
  var pg = new PassGen();
  
  //TODO this is for testing only
//  chrome.runtime.getPlatformInfo().then((Map m) {
//    window.alert(m.toString());
//  });
}

class PassGen {
  static const double _VERSION  = 1.0;
  static const String _KEY      = "r>b0!y@`+^dT6llD%X|9_o_GJ2}@lfnd/C68Cm0PGl~rvRX[Jr*Nji<2nXhwSeUEkd3&/.#V/^o6pC{DlxFni<'0J(7G4pJ_Jc%9U1h9PSnwYo7ZaRM[Wr*Mq#u%)br";
  static const String _ALNUM    = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  static const String _CHARS    = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()`-=[]\\;',./~_+{}|:\"<>?";     
  
  final DivElement           _container = querySelector('#PassGen');  
  final FormElement          _form      = querySelector('#form');
  final DivElement           _info      = querySelector('#info');
  final CheckboxInputElement _symbols   = querySelector('#symbols');
  final Element              _result    = querySelector('#result');
  final TextInputElement     _site      = querySelector('#site');
  final TextInputElement     _secret    = querySelector('#secret');
  
  PassGen() {
    _info.hidden = true;
    _result.hidden = true;
    
    try {
      var params = new chrome.TabsQueryParams()
        ..active = true
        ..currentWindow = true;
      chrome.tabs.query(params).then((tabs) {
        if (tabs.length != 1) {
          _info.text = "Found " + tabs.length.toString()
            + "active tabs (expected 1).";
        }
        _site.value = Uri.parse(tabs[0].url).host;
      });
    } catch(e) {
      _info.text = "Unable to get current website.";
    }
    
    _form.onSubmit.listen(generate);
    
  }
  
  void generate(Event e) {
    e.preventDefault();
    _info.hidden = true;
    _result.hidden = true;
    
    String site = _site.value;
    String secret = _secret.value;
    
    _info.text = '';
    if (site.length < 4 /*|| !site.contains('\.')*/) {
      _info.text = "Website too short.";
      _info.hidden = false;
      return;      
    }
    if (secret.length < 4) {
      _info.text = "Secret too short.";
      _info.hidden = false;
      return;
    }
    
    SHA256 hash = new SHA256(); 
    hash.add(UTF8.encode(site));
    hash.add(UTF8.encode(_KEY));
    hash.add(UTF8.encode(secret));
    _result.text = _hashToChars(hash.close()).join();
    
    if (_result.text.length > 0) {
      _result.hidden = false;
      window.getSelection().selectAllChildren(_result);
    }
  }
  
  
  List<String> _hashToChars(List<int> hash) {   
    List<String> chars = _symbols.checked ? _CHARS.split('') : _ALNUM.split('');    
    List<int> indexes = _splitHash(hash, chars.length);
    List<String> result = new List<String>(indexes.length);
    for (int i=0; i<indexes.length; ++i) {
      result[i] = chars[indexes[i]];
    }
    return result;
  }

  List<int> _splitHash(List<int> hash, int numChars) {
    int mid =  hash.length ~/ 2;
    List<int> split = new List<int>(mid);  
    for (int i=0; i<mid; ++i) {
      split[i] = (hash[i] + hash[mid+i]) % numChars;
    }
    return split;
  }
}

