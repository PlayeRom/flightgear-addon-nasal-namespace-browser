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
# NasalBrowser dialog class.
#
var NasalBrowserDialog = {
    #
    # Constants:
    #
    PADDING: 10,
    TIMER_DELAY: 0.2,

    #
    # Constructor.
    #
    # @return hash
    #
    new: func {
        var title = g_VersionChecker.isNewVersion()
            ? sprintf("Nasal Namespace Browser v.%s (new version %s is available)", g_Addon.version.str(), g_VersionChecker.getNewVersion())
            : sprintf("Nasal Namespace Browser v.%s", g_Addon.version.str());

        var obj = {
            parents: [
                NasalBrowserDialog,
                TransientDialog.new(
                    width : 700,
                    height: 750,
                    title : title,
                    resize: true,
                ),
            ],
        };

        obj._filterNodes = {};
        obj._addonNodePath = g_Addon.node.getPath();

        foreach (var type; FiltersDialog.TYPES) {
            obj._filterNodes[type] = props.globals.getNode(obj._addonNodePath ~ "/filters/" ~ type);
        }

        obj._filterTimer = Timer.make(me.TIMER_DELAY, obj, obj._filterCallback);

        obj._optionSortByType = props.globals.getNode(obj._addonNodePath ~ "/options/sort-by-type");

        obj._items = globals;
        obj._history = [];
        obj._path = [];
        obj._widgets = [];
        obj._resetPath();

        var scrollMargins = {
            left  : 0,
            top   : 0,
            right : 2,
            bottom: 2,
        };

        obj._scrollArea = ScrollAreaHelper.create(obj._group, scrollMargins);
        obj._scrollContent = ScrollAreaHelper.getContent(
            context: obj._scrollArea,
        );

        obj._vbox.setContentsMargins(me.PADDING, me.PADDING, 0, 0);
        obj._vbox.addItem(obj._drawTopBar());
        obj._vbox.addSpacing(me.PADDING);
        obj._vbox.addItem(obj._scrollArea, 1); # 2nd param = stretch

        obj._scrollLayout = canvas.VBoxLayout.new();
        obj._scrollArea.setLayout(obj._scrollLayout);

        obj._alreadyDisplayed = false;
        obj._displayNamespaces();

        obj._keyActions();

        obj._listeners = Listeners.new();
        obj._setListeners();

        return obj;
    },

    #
    # Destructor.
    #
    # @return void
    # @override TransientDialog
    #
    del: func {
        call(TransientDialog.del, [], me);
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
            code: func me._displayNamespaces(),
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

        me._displayNamespaces();
    },

    #
    # @return ghost  Canvas layout.
    #
    _drawTopBar: func {
        me._backBtn = canvas.gui.widgets.Button.new(me._group)
            .setText("<")
            .setFixedSize(28, 28)
            .listen("clicked", func me._handleBackButton())
            .setEnabled(false);

        var refreshBtn = canvas.gui.widgets.Button.new(me._group)
            .setText("Refresh")
            .listen("clicked", func me._displayNamespaces());

        var filtersBtn = canvas.gui.widgets.Button.new(me._group)
            .setText("Filters...")
            .listen("clicked", func FiltersDialog.new());

        me._pathLabel = canvas.gui.widgets.Label.new(me._group)
            .setText(me._getPath());

        var hBoxCtrl = canvas.HBoxLayout.new();
        hBoxCtrl.addItem(me._backBtn);
        hBoxCtrl.addItem(refreshBtn);
        hBoxCtrl.addItem(filtersBtn);
        hBoxCtrl.addStretch(1);

        var vBox = canvas.VBoxLayout.new();
        vBox.addItem(hBoxCtrl);
        vBox.addItem(me._pathLabel);

        return vBox;
    },

    #
    # @return void
    #
    _handleBackButton: func() {
        var prev = nil;
        if (size(me._history)) {
            prev = pop(me._history);
        }

        if (size(me._history)) {
            pop(me._path);

            me._items = prev == nil
                ? globals
                : prev.item;
        } else {
            me._items = globals;
            me._resetPath();
            me._history = [];
            me._backBtn.setEnabled(false);
        }

        me._pathLabel.setText(me._getPath());

        me._displayNamespaces();

        if (prev != nil) {
            me._scrollArea.scrollTo(prev.scrollX, prev.scrollY);
        }
    },

    #
    # Display current namespaces list.
    #
    # @return void
    #
    _displayNamespaces: func {
        Profiler.start("_displayNamespaces");

        me._handleScrollLayoutStretch(func {
            var children = me._getSortedChildren();

            var widgetsSize = size(me._widgets);
            var childrenSize = size(children);
            var loopSize = widgetsSize > childrenSize ? widgetsSize : childrenSize;

            for (var i = 0; i < loopSize; i += 1) {
                if (i < childrenSize) {
                    var child = children[i];
                    me._displayItem(i, widgetsSize, child.key, child.value);
                    continue;
                }

                # Hide rest of widgets
                me._widgets[i].layout.itemAt(1).setVisible(false); # button
                me._widgets[i].layout.setVisible(false);
            }
        });

        Profiler.stop();
    },

    #
    # Handle adding/removing stretch at the end of scroll layout.
    #
    # @param  func  callback
    # @return void
    #
    _handleScrollLayoutStretch: func(callback) {
        if (me._alreadyDisplayed) {
            var lastIndex = me._scrollLayout.count() - 1;
            me._scrollLayout.takeAt(lastIndex); # remove last stretch
        }

        me._alreadyDisplayed = true;

        callback();

        me._scrollLayout.addStretch(1);
    },

    #
    # @return vector  Array of {key, value} items allowed by filters and sorted.
    #
    _getSortedChildren: func() {
        var children = [];

        var processFunc = me._getProcessChildrenFunc();
        if (processFunc != nil) {
            call(processFunc, [func(key, value) {
                append(children, {
                    key: key,
                    value: value,
                });
            }], me);
        }

        return me._sortElements(children);
    },

    #
    # @return func|nil  Function to process children of current `me._items`.
    #
    _getProcessChildrenFunc: func() {
        if (ishash(me._items)) return me._getChildrenForHash;
        if (isvec(me._items))  return me._getChildrenForVector;

        return nil;
    },

    #
    # Get allowed children of hash by calling `callback` function for each.
    #
    # @param  func  callback  Function to call for each allowed child: func(key, value).
    # @return void
    #
    _getChildrenForHash: func(callback) {
        var hasArg = false;

        foreach (var key; keys(me._items)) {
            if ((key == "arg" and hasArg) or !me._isAllowedByFilters(me._items[key])) {
                continue;
            }

            if (key == "arg") {
                # Add "arg" only once
                hasArg = true;
            }

            callback(key, me._items[key]);
        }
    },

    #
    # Get allowed children of vector by calling `callback` function for each.
    #
    # @param  func  callback  Function to call for each allowed child: func(key, value).
    # @return void
    #
    _getChildrenForVector: func(callback) {
        forindex (var i; me._items) {
            if (!me._isAllowedByFilters(me._items[i])) {
                continue;
            }

            callback(i, me._items[i]);
        }
    },

    #
    # Sort vector by key or by type and then by key.
    #
    # @param  vector  items
    # @return vector  Sorted array of {key, value} items.
    #
    _sortElements: func(items) {
        if (me._optionSortByType.getBoolValue()) {
            # Sort by type first, then by key
            return sort(items, func(a, b) {
                return me._compareByType(a, b)
                    or me._compareByKey(a, b);
            });
        }

        # Sorty by key only
        return sort(items, func(a, b) me._compareByKey(a, b));
    },

    #
    # Compare two hashes by `keys` element.
    #
    # @param  hash  a
    # @param  hash  b
    # @return int  Comparison result (-1, 0, 1).
    #
    _compareByKey: func(a, b) {
        return me._compare(a.key, b.key);
    },

    #
    # Compare two hashes by type of `value` element.
    #
    # @param  hash  a
    # @param  hash  b
    # @return int  Comparison result (-1, 0, 1).
    #
    _compareByType: func(a, b) {
        return cmp(typeof(a.value), typeof(b.value));
    },

    #
    # @param  mixed  value
    # @return bool
    #
    _isAllowedByFilters: func(value) {
        var type = typeof(value);

        if (contains(me._filterNodes, type)) {
            return me._filterNodes[type].getBoolValue();
        }

        return true;
    },

    #
    # @param  scalar  scalar
    # @return string Return string converted to lower case letters.
    #
    _toLower: func(scalar) {
        if (isstr(scalar)) {
            return string.lc(scalar);
        }

        return scalar;
    },

    #
    # Compare two scalar values for sort function.
    #
    # @param  scalar  a
    # @param  scalar  b
    # @return int  Comparison result (-1, 0, 1).
    #
    _compare: func(a, b) {
        if (isnum(a)) {
            if (isnum(b)) {
                return a - b; # both numbers
            }

            return -1; # a number, b not
        }

        if (isnum(b)) {
            return 1; # b number, a not
        }

        # both not numbers (strings)
        return cmp(me._toLower(a), me._toLower(b));
    },

    #
    # @param  int  index
    # @param  int  widgetsSize
    # @param  int|string  id  Index of vector or key name of hash.
    # @param  hash|vector|scalar|func|ghost|nil  value
    # @return void
    #
    _displayItem: func(index, widgetsSize, id, value) {
        var isClickable = isvec(value) or ishash(value);
        var isBtnEnable = isClickable and size(value);

        if (index < widgetsSize) {
            # Modify existing widgets
            me._widgets[index].layout.itemAt(0).setText(me._getText(id, value)); # label
            me._widgets[index].layout.itemAt(1).setVisible(isClickable).setEnabled(isBtnEnable); # button
            me._widgets[index].layout.setVisible(true);
            me._widgets[index].childId = id;
            me._widgets[index].childValue = value;

            return;
        }

        # Add new widgets
        var label = me._getLabel(me._getText(id, value));
        var button = me._getButton(">").setVisible(isClickable).setEnabled(isBtnEnable);

        func {
            var tmpIndex = index;
            button.listen("clicked", func {
                me._goToNamespace(tmpIndex);
            });
        }();

        var hBox = canvas.HBoxLayout.new();
        hBox.addItem(label);
        hBox.addItem(button);
        hBox.addStretch(1);

        append(me._widgets, {
            layout: hBox,
            childId: id,
            childValue: value,
        });

        me._scrollLayout.addItem(hBox);
    },

    #
    # Handle click ">" button.
    #
    # @return void
    #
    _goToNamespace: func(index) {
        append(me._history, {
            item: me._items,
            scrollX: me._scrollArea._content_pos[0],
            scrollY: me._scrollArea._content_pos[1],
        });

        me._items = me._widgets[index].childValue;
        me._backBtn.setEnabled(true);

        append(me._path, {
            name: me._widgets[index].childId,
            type: typeof(me._widgets[index].childValue),
        });

        me._pathLabel.setText(me._getPath());

        me._displayNamespaces();

        me._scrollArea.scrollTo(0, 0);
    },

    #
    # Get path as string.
    #
    # @return string
    #
    _getPath: func {
        var result = "";
        forindex (var i; me._path) {
            var item = me._path[i];
            var type = i > 0 ? me._path[i - 1].type : nil;

            if (type == nil) {
                result ~= item.name;
            } elsif (type == "vector") {
                result ~= "[" ~ item.name ~ "]";
            } else {
                result ~= "." ~ item.name;
            }
        }

        return result;
    },

    #
    # Reset path to `globals` hash.
    #
    # @return void
    #
    _resetPath: func {
        me._path = [{
            name: "globals",
            type: "hash",
        }];
    },

    #
    # Get namespace label text.
    #
    # @param  int|string  id  Index of vector or key name of hash.
    # @param  scalar|hash|vector|ghost|func|nil  value
    # @return string
    #
    _getText: func(id, value) {
        var type = typeof(value);

        if (type == 'scalar') {
            return id ~ " = " ~ me._printScalarValue(value);
        }

        if (type == 'hash')   {
            var val = "";
            if (isa(value, props.Node)) {
                val = value.getValue();
                val = val == nil
                    ? ", props.Node value = nil"
                    : ", props.Node value = " ~ val;
            }

            return id ~ " = {}" ~ val ~ " (keys: " ~ size(value) ~ ")";
        }

        if (type == 'vector') {
            return id ~ " = [] (items: " ~ size(value) ~ ")";
        }

        if (type == 'ghost')  {
            return id ~ " = <ghost " ~ ghosttype(value) ~ ">";
        }

        if (type == 'nil')    {
            return id ~ " = nil";
        }

        return id ~ " = <" ~ type ~ ">"; # func
    },

    #
    # Return string value with quotes.
    #
    # @param  int|string|double  value
    # @return string
    #
    _printScalarValue: func(value) {
        if (isstr(value)) {
            return '"' ~ value ~ '"';
        }

        return value;
    },

    #
    # @param  string  text  Label text.
    # @return ghost  Label widget.
    #
    _getLabel: func(text) {
        return canvas.gui.widgets.Label.new(me._scrollContent)
            .setText(text);
    },

    #
    # @param  string  text  Label of button.
    # @return ghost  Button widget.
    #
    _getButton: func(text) {
        return canvas.gui.widgets.Button.new(me._scrollContent)
            .setText(text)
            .setFixedSize(26, 26);
    },

    #
    # Handle keydown listener for window.
    #
    # @return void
    #
    _keyActions: func() {
        me._window.addEventListener("keydown", func(event) {
               if (event.key == "Up"     or event.key == "Down")     me._handleScrollKey(true,  event.key == "Up");
            elsif (event.key == "PageUp" or event.key == "PageDown") me._handleScrollKey(false, event.key == "PageUp");
        });
    },

    #
    # @param  bool  isArrow  If true then arrow up/down keys, otherwise page up/down keys.
    # @param  bool  isUp  If true then dy must be converted to negative.
    # @return void
    #
    _handleScrollKey: func(isArrow, isUp) {
        var dy = ScrollAreaHelper.getScrollPageHeight(me._scrollArea);

        if (isArrow) {
            dy /= 20;
        }

        if (isUp) {
            dy = -dy;
        }

        me._scrollArea.vertScrollBarBy(dy);
    },
};
