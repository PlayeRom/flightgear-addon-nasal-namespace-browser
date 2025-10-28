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

        obj._filters = Filters.new(Callback.new(obj._updateFilters, obj));
        obj._nsCollection = NsCollection.new(obj._filters);
        obj._nsPath = NsPath.new();
        obj._widgets = WidgetCollection.new();

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

        obj._widgetScroll = WidgetHelper.new(obj._scrollContent);
        obj._widgetGroup = WidgetHelper.new(obj._group);

        obj._vbox.setContentsMargins(me.PADDING, me.PADDING, 0, 0);
        obj._vbox.addItem(obj._drawTopBar());
        obj._vbox.addSpacing(me.PADDING);
        obj._vbox.addItem(obj._scrollArea, 1); # 2nd param = stretch

        obj._scrollLayout = canvas.VBoxLayout.new();
        obj._scrollArea.setLayout(obj._scrollLayout);

        obj._alreadyDisplayed = false;
        obj._displayNamespaces();

        obj._keyActions();

        return obj;
    },

    #
    # Destructor.
    #
    # @return void
    # @override TransientDialog
    #
    del: func {
        me._filters.del();

        call(TransientDialog.del, [], me);
    },

    #
    # Callback function called when filters or options are changed.
    #
    # @return void
    #
    _updateFilters: func() {
        me._displayNamespaces();
    },

    #
    # @return ghost  Canvas layout.
    #
    _drawTopBar: func {
        me._backBtn = me._widgetGroup.getButton("<", 28, func me._handleBackButton())
            .setEnabled(false);

        var refreshBtn = me._widgetGroup.getButton("Refresh", func me._displayNamespaces());

        var filtersBtn = me._widgetGroup.getButton("Filters...", func FiltersDialog.new());

        var inputSearch = me._widgetGroup.getLineEdit("", 200, func(e) me._searchKey(e.detail.text))
            .setPlaceholder("Search...");

        var hBoxCtrl = canvas.HBoxLayout.new();
        hBoxCtrl.addItem(me._backBtn);
        hBoxCtrl.addItem(refreshBtn);
        hBoxCtrl.addItem(filtersBtn);
        hBoxCtrl.addItem(inputSearch);
        hBoxCtrl.addStretch(1);

        me._pathLabel = me._widgetGroup.getLabel(me._nsPath.get());

        var vBox = canvas.VBoxLayout.new();
        vBox.addItem(hBoxCtrl);
        vBox.addItem(me._pathLabel);

        return vBox;
    },

    #
    # @return void
    #
    _handleBackButton: func() {
        var prev = me._nsCollection.popHistory();

        if (me._nsCollection.getHistorySize()) {
            me._nsPath.pop();
        } else {
            me._nsPath.reset();
            me._backBtn.setEnabled(false);
        }

        me._pathLabel.setText(me._nsPath.get());

        me._displayNamespaces();

        if (prev != nil) {
            me._scrollArea.scrollTo(prev.scrollX, prev.scrollY);
        }
    },

    #
    # @param  string  search  Text to search.
    # @return void
    #
    _searchKey: func(search) {
        var posY = me._widgets.searchTextInLabel(search);
        if (posY != nil) {
            var scale = ScrollAreaHelper.getScrollHeightScale(me._scrollArea);
            me._scrollArea.vertScrollBarTo(posY * scale);
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
            var children = me._nsCollection.getSortedChildren();

            var widgetsSize = me._widgets.size();
            var childrenSize = size(children);
            var loopSize = widgetsSize > childrenSize ? widgetsSize : childrenSize;

            for (var i = 0; i < loopSize; i += 1) {
                if (i < childrenSize) {
                    var child = children[i];
                    me._displayItem(i, widgetsSize, child.key, child.value);
                    continue;
                }

                # Hide rest of widgets
                me._widgets.getButtonByIndex(i).setVisible(false); # button
                me._widgets.getLayout(i).setVisible(false);
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
    # @param  int  index
    # @param  int  widgetsSize
    # @param  int|string  id  Index of vector or key name of hash.
    # @param  hash|vector|scalar|func|ghost|nil  value
    # @return void
    #
    _displayItem: func(index, widgetsSize, id, value) {
        var isClickable = isvec(value) or ishash(value);
        var isBtnEnable = isClickable and size(value);
        var labelText = me._getText(id, value);

        if (index < widgetsSize) {
            # Modify existing widgets
            me._widgets.updateItem(index, labelText, id, value, isClickable, isBtnEnable);
            return;
        }

        # Add new widgets
        var label = me._widgetScroll.getLabel(labelText);
        var button = me._widgetScroll.getButton(">")
            .setVisible(isClickable)
            .setEnabled(isBtnEnable)
            .setFixedSize(26, 26);

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

        me._widgets.addItem(hBox, id, value);

        me._scrollLayout.addItem(hBox);
    },

    #
    # Handle click ">" button.
    #
    # @param  int  index
    # @return void
    #
    _goToNamespace: func(index) {
        var (childId, childValue) = me._widgets.getChildData(index);

        me._nsCollection.pushHistory(
            scrollPos: me._scrollArea._content_pos,
            newItems: childValue,
        );

        me._backBtn.setEnabled(true);

        me._nsPath.push(childId, typeof(childValue));

        me._pathLabel.setText(me._nsPath.get());

        me._displayNamespaces();

        me._scrollArea.scrollTo(0, 0);
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
