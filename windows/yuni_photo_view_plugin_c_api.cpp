#include "include/yuni_photo_view/yuni_photo_view_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "yuni_photo_view_plugin.h"

void YuniPhotoViewPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  yuni_photo_view::YuniPhotoViewPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
