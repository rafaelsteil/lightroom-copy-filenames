--[[
Plug-in manifest. Lightroom evaluates this file in a restricted environment
(no import/require) to decide whether the plug-in can load and where it
appears in the UI.

SDK 6 matches Lightroom 6 / Classic CC 2015, which is old enough to cover
current Classic while still using a stable dialog and prefs API. The
minimum version is the same because a higher LrSdkVersion already refuses
to load on older Lightroom.

The command lives under Library > Plug-in Extras because that is where
getTargetPhotos() reflects the filmstrip selection. It is disabled until
photos are selected so the menu cannot copy the entire filmstrip by
accident (the SDK returns every photo in view when the selection is empty).
]]

return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'app.aurori.lightroom.copyfilenames',
    LrPluginName = 'Copy Selected Filenames',
    VERSION = { major = 1, minor = 2, revision = 0 },

    LrLibraryMenuItems = {
        {
            title = 'Copy Selected Filenames',
            file = 'CopyFilenames.lua',
            enabledWhen = 'photosSelected',
        },
    },
}
