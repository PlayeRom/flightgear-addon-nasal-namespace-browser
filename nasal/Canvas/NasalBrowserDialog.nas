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

        obj._widgets = [];
        obj._foundIndex = nil;

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

        var inputSearch = canvas.gui.widgets.LineEdit.new(me._group)
            .setPlaceholder("Search...")
            .setText("")
            .setFixedSize(200, 28)
            .listen("editingFinished", func(e) me._searchKey(e.detail.text));

        var hBoxCtrl = canvas.HBoxLayout.new();
        hBoxCtrl.addItem(me._backBtn);
        hBoxCtrl.addItem(refreshBtn);
        hBoxCtrl.addItem(filtersBtn);
        hBoxCtrl.addItem(inputSearch);
        hBoxCtrl.addStretch(1);

        me._pathLabel = canvas.gui.widgets.Label.new(me._group)
            .setText(me._nsPath.get());

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
        var widgetsSize = size(me._widgets);

        var i = 0;
        var foundIndexTmp = me._foundIndex;
        if (foundIndexTmp != nil) {
            i = foundIndexTmp + 1;

            if (foundIndexTmp < widgetsSize) {
                # Back color to default
                me._widgets[foundIndexTmp].layout.itemAt(0)
                    .setColor(canvas.style.getColor("text_color"));
            }
        }

        me._foundIndex = nil;

        if (search == nil or search == "") {
            return;
        }

        search = string.lc(search);

        me._foundIndex = me._searchInternal(search, i, widgetsSize);

        if (foundIndexTmp != nil and foundIndexTmp > 0 and me._foundIndex == nil) {
            # Not found, but the search did not start from the beginning,
            # so the search should be performed again from the beginning.
            me._foundIndex = me._searchInternal(search, 0, widgetsSize);
        }
    },

    #
    # @param  string  search  Text to search.
    # @param  int  i  Initial index.
    # @param  int  widgetsSize
    # @return int|nil  Index of found text or nil if not found.
    #
    _searchInternal: func(search, i, widgetsSize) {
        for (; i < widgetsSize; i += 1) {
            var layout = me._widgets[i].layout;
            var label = layout.itemAt(0);

            # TODO: Use the Label widget method when available (label.getText()):
            var labelText = string.lc(label._view._text.getText());

            if (find(search, labelText) >= 0) {
                if (!layout.isVisible()) {
                    # If the layout is invisible, it means that we have already searched all visible ones,
                    # so we have to exit.
                    return nil;
                }

                var (x, y, w, h) = label.geometry();

                var scale = me._getScrollHeightScale();

                me._scrollArea.vertScrollBarTo(y * scale);

                # Set color to red of found label
                label.setColor([1, 0, 0]);

                return i;
            }
        }

        return nil;
    },

    #
    # @return double
    #
    _getScrollHeightScale: func() {
        # TODO: use ScrollArea methods as they become available.
        var scrollTrackHeight = me._scrollArea._scroller_delta[1];
        var contentHeight     = me._scrollArea._max_scroll[1];
        if (contentHeight == 0) {
            contentHeight = 1; # prevent divide by 0
        }

        return scrollTrackHeight / contentHeight;
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
            var item = me._widgets[index];
            var label = item.layout.itemAt(0);

            label.setText(me._getText(id, value));
            label.setColor(canvas.style.getColor("text_color"));

            item.layout.itemAt(1).setVisible(isClickable).setEnabled(isBtnEnable); # button
            item.layout.setVisible(true);

            item.childId = id;
            item.childValue = value;

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
    # @param  int  index
    # @return void
    #
    _goToNamespace: func(index) {
        me._nsCollection.pushHistory(
            scrollPos: me._scrollArea._content_pos,
            newItems: me._widgets[index].childValue,
        );

        me._backBtn.setEnabled(true);

        me._nsPath.append(
            me._widgets[index].childId,
            typeof(me._widgets[index].childValue),
        );

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
