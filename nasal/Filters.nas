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

#
# Class for handle filters.
#
var Filters = {
    #
    # Constants:
    #
    TIMER_DELAY: 0.2,

    #
    # Constructor.
    #
    # @param  hash  updateCallback  Callback object.
    # @return hash
    #
    new: func(updateCallback) {
        var obj = {
            parents: [
                Filters,
            ],
            _updateCallback: updateCallback,
        };

        obj._filterNodes = {};
        obj._addonNodePath = g_Addon.node.getPath();

        foreach (var type; FiltersDialog.TYPES) {
            obj._filterNodes[type] = props.globals.getNode(obj._addonNodePath ~ "/filters/" ~ type);
        }

        obj._filterTimer = Timer.make(me.TIMER_DELAY, obj, obj._filterCallback);

        obj._optionSortByType = props.globals.getNode(obj._addonNodePath ~ "/options/sort-by-type");

        obj._listeners = Listeners.new();
        obj._setListeners();

        return obj;
    },

    #
    # Destructor.
    #
    # @return void
    #
    del: func() {
        me._listeners.del();
    },

    #
    # @param  mixed  value
    # @return bool
    #
    isAllowed: func(value) {
        var type = typeof(value);

        if (contains(me._filterNodes, type)) {
            return me._filterNodes[type].getBoolValue();
        }

        return true;
    },

    #
    # @return bool
    #
    isSortByType: func() {
        return me._optionSortByType.getBoolValue();
    },

    #
    # Set listeners.
    #
    # @return void
    #
    _setListeners: func() {
        foreach (var type; FiltersDialog.TYPES) {
            me._listeners.add(
                node: me._filterNodes[type],
                code: func me._handleFilterListener(),
                type: Listeners.ON_CHANGE_ONLY,
            );
        }

        me._listeners.add(
            node: me._optionSortByType,
            code: func me._updateCallback.invoke(),
            type: Listeners.ON_CHANGE_ONLY,
        );
    },

    #
    # Use a timer to delay screen refresh when multiple filters change their
    # state "simultaneously" (within a very short time interval).
    #
    # @return void
    #
    _handleFilterListener: func() {
        me._filterTimer.isRunning
            ? me._filterTimer.restart(me.TIMER_DELAY)
            : me._filterTimer.start();
    },

    #
    # Filter timer callback.
    #
    # @return void
    #
    _filterCallback: func() {
        me._filterTimer.stop();

        me._updateCallback.invoke();
    },
};
