# The plugin finds the optional Push and Billing modules by name, so an app that adds those
# artifacts keeps them under R8.
-keep class dev.pingfront.push.Push { public static ** INSTANCE; }
-keep class dev.pingfront.billing.Billing { public static ** INSTANCE; public ** invoke(java.util.List); }
