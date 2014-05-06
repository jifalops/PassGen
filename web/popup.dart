import 'dart:html';
import 'package:lawndart/lawndart.dart';
import 'package:chrome/chrome_ext.dart' as chrome;
import 'PassGen.dart';
//import 'dart:js';

const int 
    _MIN_PASS_LEN   = 4,
    _MAX_PASS_LEN   = 32,
    _MIN_SITE_LEN   = 4,
    _MAX_SITE_LEN   = 64,
    _MIN_SECRET_LEN = 4,
    _MAX_SECRET_LEN = 63,
    
    _ERR_NONE          = 0,
    _ERR_TAB_COUNT     = 1,
    _ERR_UNKNOWN_HOST  = 2,
    _ERR_HOST_SHORT    = 3,
    _ERR_HOST_LONG     = 4,
    _ERR_SECRET_SHORT  = 5,
    _ERR_SECRET_LONG   = 6,
    _ERR_GENPASS_SHORT = 7,
    _ERR_GENPASS_LONG  = 8,
    _ERR_AUTOFILL_PASS = 9;

const String
  _DB_NAME         = "PassGen",
  _DB_STORE        = "state",
  _KEY_PASS_LEN    = "passLen",    
  _KEY_SECRET      = "secret",
  _KEY_SAVE_SECRET = "saveSecret",
  _KEY_AUTO_HOST   = "autoHost",
  _KEY_USE_LOWER   = "useLower",
  _KEY_USE_UPPER   = "useUpper",
  _KEY_USE_NUMBERS = "useNumbers",
  _KEY_USE_SYMBOLS = "useSymbols";
 
final List<String> _TOP_LEVEL_DOMAINS = [
  'com', 'org', 'net', 'int', 'edu', 'gov', 'mil',
  'biz', 'info', 'mobi', 'name', 'wiki', 'xxx'
];
  

final DivElement           _container  = querySelector('#PassGen');  
final FormElement          _form       = querySelector('#form');
final DivElement           _error      = querySelector('#error');
final DivElement           _result     = querySelector('#result');
final TextInputElement     _site       = querySelector('#site');
final TextInputElement     _secret     = querySelector('#secret');
final CheckboxInputElement _saveSecret = querySelector('#saveSecret');
final SelectElement        _passLength = querySelector('#passLen');
final CheckboxInputElement _autoHost   = querySelector('#autoHost');
final CheckboxInputElement _lower      = querySelector('#lower');
final CheckboxInputElement _upper      = querySelector('#upper');
final CheckboxInputElement _numbers    = querySelector('#numbers');
final CheckboxInputElement _symbols    = querySelector('#symbols');
final SpanElement          _autofill   = querySelector('#autofill');
final SpanElement          _autofillResults     = querySelector('#autofillResults');
final DivElement           _autofillContainer   = querySelector('#autofillContainer');

final Store _store = new Store(_DB_NAME, _DB_STORE);
final PassGen _pg = new PassGen();

int _passLen = 16;

void main() {             
  // DOM is fully loaded.         
  _error.hidden = true;
  _result.hidden = true;
  _autofillContainer.hidden = true;
  
  _loadState();
  _prefillWebsite();
  _secret.focus();
  
  _form.onSubmit.listen(_onSubmitted);
  
  
  _autofill.onClick.listen(_onAutofill);
  
  _saveSecret.onChange.listen((e) => _store.open().then((_) {
    _store.save(_saveSecret.checked.toString(), _KEY_SAVE_SECRET);
    if (_saveSecret.checked) {
      _doSaveSecret();
    } else {
      _store.removeByKey(_KEY_SECRET);
    }
  }));
  _lower.onChange.listen((e) => _store.open().then((_) => _store.save(_lower.checked.toString(), _KEY_USE_LOWER)));
  _upper.onChange.listen((e) => _store.open().then((_) => _store.save(_upper.checked.toString(), _KEY_USE_UPPER)));
  _numbers.onChange.listen((e) => _store.open().then((_) => _store.save(_numbers.checked.toString(), _KEY_USE_NUMBERS)));
  _symbols.onChange.listen((e) => _store.open().then((_) => _store.save(_symbols.checked.toString(), _KEY_USE_SYMBOLS)));
  _autoHost.onChange.listen((e) => _store.open().then((_) {
    _prefillWebsite();
    _store.save(_autoHost.checked.toString(), _KEY_AUTO_HOST);    
  }));
  _passLength.onChange.listen((e) => _store.open().then((_) {
    _store.save(_passLength.value, _KEY_PASS_LEN);
    _passLen = int.parse(_passLength.value);
  }));
}

void _onSubmitted(Event e) {  
  e.preventDefault();
  _error.hidden = true;
  _result.hidden = true;
  _autofillContainer.hidden = true;
  
  _saveState();
  
  int errno = checkInputs();
  if (errno == _ERR_NONE) {
    int charTypes = 0;
    if (_lower.checked) charTypes |= PassGen.CHAR_LOWER;
    if (_upper.checked) charTypes |= PassGen.CHAR_UPPER;
    if (_numbers.checked) charTypes |= PassGen.CHAR_NUMBERS;
    if (_symbols.checked) charTypes |= PassGen.CHAR_SYMBOLS;    
print('charTypes: ' + charTypes.toString());
    _result.text = _pg.hashAndConvert(_site.value + _secret.value, _passLen, charTypes);
    _result.hidden = false;
    _autofillContainer.hidden = false;
    window.getSelection().selectAllChildren(_result);
  } else {
    showError(errno);
  }
}

void _onAutofill(Event e) {
  final String pass = _result.text;
  try {
    chrome.tabs.executeScript(new chrome.InjectDetails(
      code: 
'''
      var inputs = document.getElementsByTagName("input");    
      for (var i=0; i<inputs.length; i++) {
        if (inputs[i].type.toLowerCase() == "password" && inputs[i].value.length == 0) {
          inputs[i].value = "$pass";
        }
      }
'''      
    )).then((_) => window.getSelection().selectAllChildren(_result));
  } catch(e) {
    showError(_ERR_AUTOFILL_PASS);
  } 
}

void _doSaveSecret() {
  _store.save(_pg.cipher(_secret.value, true), _KEY_SECRET);
}


void _saveState() {
  _store.open()
    .then((_) => _store.nuke())
    .then((_) => _store.save(_passLength.value, _KEY_PASS_LEN))
    .then((_) => _store.save(_saveSecret.checked.toString(), _KEY_SAVE_SECRET))
    .then((_) => _store.save(_lower.checked.toString(), _KEY_USE_LOWER))
    .then((_) => _store.save(_upper.checked.toString(), _KEY_USE_UPPER))
    .then((_) => _store.save(_numbers.checked.toString(), _KEY_USE_NUMBERS))
    .then((_) => _store.save(_symbols.checked.toString(), _KEY_USE_SYMBOLS))
    .then((_) => _store.save(_autoHost.checked.toString(), _KEY_AUTO_HOST))
    .then((_) {
      if (_saveSecret.checked && _store.isOpen) {
        _doSaveSecret();
      }
    });
}

void _loadState() {
  _store.open()
    .then((_) => _store.getByKey(_KEY_PASS_LEN))
    .then((value) {
      if (value != null) _passLen = int.parse(value);
    })
    .then((_) => _addLengthOptions())
    .then((_) => _store.getByKey(_KEY_USE_LOWER))
    .then((value) {
      if (value != null) _lower.checked = value == true.toString();
    })
    .then((_) => _store.getByKey(_KEY_USE_UPPER))
    .then((value) {
      if (value != null) _upper.checked = value == true.toString();
    })
    .then((_) => _store.getByKey(_KEY_USE_NUMBERS))
    .then((value) {
      if (value != null) _numbers.checked = value == true.toString();
    })
    .then((_) => _store.getByKey(_KEY_USE_SYMBOLS))
    .then((value) {
      if (value != null) _symbols.checked = value == true.toString();
    })
    .then((_) => _store.getByKey(_KEY_AUTO_HOST))
    .then((value) {
      if (value != null) _autoHost.checked = value == true.toString();
    })
    .then((_) => _store.getByKey(_KEY_SAVE_SECRET))
    .then((value) {      
      if (value != null) _saveSecret.checked = value == true.toString();
      if (_saveSecret.checked) {
        _store.getByKey(_KEY_SECRET)
          .then((value) {
            if (value != null) _secret.value = _pg.cipher(value, false);
        });
      }
    });
}

void _addLengthOptions() {
  _passLength.children.clear();
  String s; 
  for (int i=_MIN_PASS_LEN; i<=_MAX_PASS_LEN; ++i) {
    s = i.toString();
    _passLength.children.add(
        new OptionElement()
        ..value=s
        ..text=s
        ..selected=(i==_passLen));
  }
}

void _prefillWebsite() {
  try {
    var params = new chrome.TabsQueryParams()
      ..active = true
      ..currentWindow = true;
    chrome.tabs.query(params).then((tabs) {
      if (tabs.length != 1) {
        showError(_ERR_TAB_COUNT, tabs.length);
      }
      
      String host = Uri.parse(tabs[0].url).host; 
      var parts = host.split('.');
      var len = parts.length;
      
      if (_autoHost.checked && len > 2) {        
        int offset = 3;
        if (_TOP_LEVEL_DOMAINS.contains(parts.last)) {
          offset = 2;
        }      
        host = parts.getRange(len - offset, len).join('.');        
      }
      _site.value = host;
    });
  } catch(e) {
    showError(_ERR_UNKNOWN_HOST);
  }
}

//TODO allow multiple errors on different lines
int checkInputs() {  
  if (_site.value.length < _MIN_SITE_LEN /*|| !site.contains('\.')*/) {
    return _ERR_HOST_SHORT;    
  } else if (_site.value.length > _MAX_SITE_LEN) {
    return _ERR_HOST_LONG;
  }
  
  if (_secret.value.length < _MIN_SECRET_LEN) {
    return _ERR_SECRET_SHORT;   
  } else if (_secret.value.length > _MAX_SECRET_LEN) {
    return _ERR_SECRET_LONG;
  }
  
  if (int.parse(_passLength.value) < _MIN_PASS_LEN) {
    return _ERR_GENPASS_SHORT;
  } else if (int.parse(_passLength.value) > _MAX_PASS_LEN) {
    return _ERR_GENPASS_LONG; 
  }
  return _ERR_NONE;
}

void showError(int errno, [var arg1]) {  
  String err = '';
  switch (errno) {
    case _ERR_TAB_COUNT:
      err = 'Found ' + arg1.toString() + ' active tabs (expected 1).';      
      break;
    case _ERR_UNKNOWN_HOST:
      err = 'Unable to get current website.';
      break;
    case _ERR_HOST_SHORT:
      err = 'Website too short.';
      break;
    case _ERR_HOST_LONG:
      err = 'Website too long.';  
      break;
    case _ERR_SECRET_SHORT:
      err = 'Secret too short.';                
      break;
    case _ERR_SECRET_LONG:
      err = 'Secret too long.';          
      break;
    case _ERR_GENPASS_SHORT:
      err = 'Generated password too short.';                
      break;
    case _ERR_GENPASS_LONG:
      err = 'Generated password too long.';          
      break;
    case _ERR_AUTOFILL_PASS:
      err = 'Unable to autofill password.';          
      break;
    default:
      print('showError(): Unkown errno.');
  }
  _error.text = err;
  if (err.length > 0) _error.hidden = false;
}


