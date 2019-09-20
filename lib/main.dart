import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() => runApp(App());

class App extends StatefulWidget {
createState() => AppState();
}

class AppState extends State<App> {
final _controller = TextEditingController();
final _rootRef = FirebaseDatabase.instance.reference();
final _auth = FirebaseAuth.instance;
final _google = GoogleSignIn();
final _theme = ThemeData(
primaryColor: Color(0xff9c003d),
accentColor: Color(0xffffc819),
cursorColor: Color(0xffd80034));

FirebaseUser _user;
bool _isSetup = true;
bool _isLoading = true;
String _channel = 'instant';
String _composingKey;
var _subscription;

@override
void initState() {
super.initState();
_subscription = _auth.onAuthStateChanged.listen((user) {
setState(() {
_isLoading = false;
_user = user;
_channel = user == null ? 'instant' : _channel;
_isSetup = _channel == 'instant';
});
});
}

@override
void dispose() {
_subscription?.cancel();
_controller?.dispose();
super.dispose();
}

Widget build(BuildContext context) {
return MaterialApp(
theme: _theme,
home: Scaffold(
appBar: AppBar(
title: Text('#$_channel'),
actions: [
FlatButton(
textColor: _theme.accentColor,
onPressed: _user != null ? _auth.signOut : _signIn,
child: Text(_user != null ? 'LOGOUT' : 'LOGIN'))
],
),
body: Container(
decoration: BoxDecoration(
image: DecorationImage(
fit: BoxFit.cover,
image: AssetImage('assets/bg.png'),
),
),
child: Column(
children: [_buildMain(), _buildComposer()],
),
),
),
);
}

Widget _buildMain() =>
Expanded(child: _isLoading ? _buildLoading() : _buildList());

Widget _buildList() {
return FirebaseAnimatedList(
key: Key(_channel),
defaultChild: _buildLoading(),
query: _rootRef.child(_channel),
padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
reverse: true,
sort: (l, r) => r.key.compareTo(l.key),
itemBuilder: (_, snapshot, animation, index) => SizeTransition(
axisAlignment: -1,
sizeFactor: animation,
child: _buildMessage(snapshot.value['text'], snapshot.value['name'],
_user != null && _user.uid == snapshot.value['uid']),
),
);
}

Widget _buildLoading() => Center(child: CircularProgressIndicator());

Widget _buildComposer() => Container(
margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
child: Material(
elevation: 1,
borderRadius: BorderRadius.circular(80),
child: _buildTextField()));

Widget _buildTextField() => TextField(
enabled: _user != null,
controller: _controller,
onChanged: _onChanged,
onSubmitted: _onSubmitted,
onEditingComplete: () => {},
textCapitalization: TextCapitalization.sentences,
textInputAction: TextInputAction.send,
inputFormatters: _isSetup
? [WhitelistingTextInputFormatter(RegExp('[a-zA-Z]'))]
: null,
maxLines: null,
decoration: InputDecoration(
contentPadding: EdgeInsets.all(16),
border: InputBorder.none,
prefixIcon: _isSetup ? Icon(IconData(('#').codeUnitAt(0))) : null,
hintText: _isSetup ? 'channel' : 'Send a message',
));

Widget _buildMessage(String text, String name, bool isSender) {
return Align(
alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
child: Container(
margin: EdgeInsets.only(
bottom: 8, left: isSender ? 56 : 0, right: isSender ? 0 : 56),
padding: EdgeInsets.all(8),
decoration: BoxDecoration(
border: Border.all(width: 0.5, color: _theme.dividerColor),
color: isSender ? _theme.accentColor : _theme.cardColor,
borderRadius: BorderRadius.circular(8),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Visibility(
visible: !isSender,
child: Container(
padding: EdgeInsets.only(bottom: 4),
child: Text(
name,
style: TextStyle(
color: _theme.primaryColor,
fontWeight: FontWeight.bold,
),
),
),
),
Text(text, style: TextStyle(fontSize: 16))
],
),
),
);
}

void _onChanged(text) {
if (text.startsWith('#')) {
setState(() => _isSetup = true);
_controller.clear();
} else if (!_isSetup && _channel != 'instant') {
var channelRef = _rootRef.child(_channel);
var key = _composingKey ?? channelRef.push().key;
channelRef.child(key).set(text.isEmpty
? null
: {'text': text, 'uid': _user.uid, 'name': _user.displayName});
setState(() => _composingKey = text.isEmpty ? null : key);
}
}

void _onSubmitted(text) {
if (text.isEmpty) return;
setState(() {
_channel = _isSetup ? text.toLowerCase() : _channel;
_isSetup = _channel == 'instant';
_composingKey = null;
});
_controller.clear();
}

void _signIn() async {
setState(() => _isLoading = true);
try {
var user = (await _google.signInSilently()) ?? (await _google.signIn());
var auth = await user.authentication;
await _auth.signInWithCredential(GoogleAuthProvider.getCredential(
accessToken: auth.accessToken, idToken: auth.idToken));
} catch (e) {
setState(() => _isLoading = false);
}
}
}
