//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <dynamic_color/dynamic_color_plugin.h>
#include <ffmpeg_kit_flutter_new_audio/f_fmpeg_kit_flutter_new_audio_plugin.h>
#include <flutter_gemma/flutter_gemma_plugin.h>
#include <flutter_secure_storage_linux/flutter_secure_storage_linux_plugin.h>
#include <flutter_sound/flutter_sound_plugin.h>
#include <flutter_tts/flutter_tts_plugin.h>
#include <syncfusion_pdfviewer_linux/syncfusion_pdfviewer_linux_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) dynamic_color_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DynamicColorPlugin");
  dynamic_color_plugin_register_with_registrar(dynamic_color_registrar);
  g_autoptr(FlPluginRegistrar) ffmpeg_kit_flutter_new_audio_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FFmpegKitFlutterNewAudioPlugin");
  f_fmpeg_kit_flutter_new_audio_plugin_register_with_registrar(ffmpeg_kit_flutter_new_audio_registrar);
  g_autoptr(FlPluginRegistrar) flutter_gemma_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterGemmaPlugin");
  flutter_gemma_plugin_register_with_registrar(flutter_gemma_registrar);
  g_autoptr(FlPluginRegistrar) flutter_secure_storage_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterSecureStorageLinuxPlugin");
  flutter_secure_storage_linux_plugin_register_with_registrar(flutter_secure_storage_linux_registrar);
  g_autoptr(FlPluginRegistrar) flutter_sound_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterSoundPlugin");
  flutter_sound_plugin_register_with_registrar(flutter_sound_registrar);
  g_autoptr(FlPluginRegistrar) flutter_tts_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterTtsPlugin");
  flutter_tts_plugin_register_with_registrar(flutter_tts_registrar);
  g_autoptr(FlPluginRegistrar) syncfusion_pdfviewer_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SyncfusionPdfviewerLinuxPlugin");
  syncfusion_pdfviewer_linux_plugin_register_with_registrar(syncfusion_pdfviewer_linux_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
}
