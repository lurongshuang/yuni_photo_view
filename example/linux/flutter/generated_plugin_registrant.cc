//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <yuni_photo_view/yuni_photo_view_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) yuni_photo_view_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "YuniPhotoViewPlugin");
  yuni_photo_view_plugin_register_with_registrar(yuni_photo_view_registrar);
}
