import 'dart:js_interop';

@JS('droplyricSpotifyCall')
external JSPromise<JSString> _call(JSString action, JSString argument);
@JS('droplyricSpotifyState')
external JSString _state();
const spotifyWebSupported = true;
Future<String> spotifyCall(String action, [String argument = '']) async =>
    (await _call(action.toJS, argument.toJS).toDart).toDart;
String spotifyState() => _state().toDart;
