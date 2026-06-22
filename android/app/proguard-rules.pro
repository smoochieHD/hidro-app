# Regras ProGuard/R8 para builds de release (minifyEnabled + shrinkResources).

# --- Flutter wrapper: nunca remover/ofuscar, é o motor da app ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- flutter_local_notifications: usa GSON internamente para serializar
# detalhes de notificações agendadas. Sem estas regras, o R8 pode remover
# informação de tipo genérico necessária e as notificações agendadas
# deixam de funcionar silenciosamente em release.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# --- Google Play Core (deferred components): não usamos esta
# funcionalidade, mas o Flutter engine referencia-a sempre. Sem isto, o
# R8 falha por "missing classes" mesmo sem a usarmos.
-dontwarn com.google.android.play.core.**
