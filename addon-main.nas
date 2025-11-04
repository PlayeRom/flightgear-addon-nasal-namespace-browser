#
# NasalNamespaceBrowser Add-on for FlightGear
#
# Written and developer by Roman Ludwicki (PlayeRom, SP-ROM)
#
# Copyright (C) 2025 Roman Ludwicki
#
# NasalNamespaceBrowser is an Open Source project and it is licensed
# under the GNU Public License v3 (GPLv3)
#

io.include('framework/nasal/Application.nas');

#
# Global object of filters dialog.
#
var g_FiltersDialog = nil;

#
# Global object of about dialog.
#
var g_AboutDialog = nil;

#
# Main add-on function.
#
# @param  ghost  addon  The addons.Addon object.
# @return void
#
var main = func(addon) {
    logprint(LOG_INFO, addon.name, ' Add-on initialized from path ', addon.basePath);

    Config.useVersionCheck.byGitTag = true;

    Application
        .hookFilesExcludedFromLoading(func {
            return [
                '/nasal/Legacy/NasalBrowserV1.nas',
            ];
        })
        .hookOnInitCanvas(func {
            g_FiltersDialog = FiltersDialog.new();
            g_AboutDialog = AboutDialog.new();
        })
        .create(addon);
};

#
# This function is for addon development only. It is called on addon reload. The addons system will replace
# setlistener() and maketimer() to track this resources automatically for you.
#
# Listeners created with setlistener() will be removed automatically for you. Timers created with maketimer() will have
# their stop() method called automatically for you. You should NOT use settimer anymore, see wiki at
# https://wiki.flightgear.org/Nasal_library#maketimer()
#
# Other resources should be freed by adding the corresponding code here, e.g. `myCanvas.del();`.
#
# @param  ghost  addon  The addons.Addon object.
# @return void
#
var unload = func(addon) {
    Log.print('unload');
    Application.unload();

    if (g_FiltersDialog != nil) {
        g_FiltersDialog.del();
    }

    if (g_AboutDialog != nil) {
        g_AboutDialog.del();
    }
};
