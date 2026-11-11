# pingfront_flutter finds the factory by name, so it stays under R8.
-keep class dev.pingfront.flutter.superwall.SuperwallAdapterFactory { public static ** module(java.util.Map); }
