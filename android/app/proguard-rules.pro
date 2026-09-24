# Flutter's own classes are kept by the engine's consumer rules; these cover
# what this app adds.

# Generated plugin registrant is referenced reflectively by the embedding.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# The launcher aliases are named as strings in MainActivity (the icon
# channel), and the activity is the alias target, so R8 must not rename or
# drop it.
-keep class com.ebseca.weakspot.MainActivity { *; }
