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

        obj._items = globals;
        obj._history = [];
        obj._path = [];
        obj._widgets = [];
        obj._resetPath();

        var scrollMargins = {
            left  : me.PADDING,
            top   : me.PADDING,
            right : 2,
            bottom: 0,
        };

        obj._scrollArea = ScrollAreaHelper.create(obj._group, scrollMargins);
        obj._scrollContent = ScrollAreaHelper.getContent(
            context: obj._scrollArea,
        );

        obj._vbox.addSpacing(me.PADDING);
        obj._vbox.addItem(obj._drawTopBar());
        obj._vbox.addSpacing(me.PADDING);
        obj._vbox.addItem(obj._scrollArea, 1); # 2nd param = stretch

        obj._scrollLayout = canvas.VBoxLayout.new();
        obj._scrollArea.setLayout(obj._scrollLayout);

        obj._displayRoot();

        obj._scrollLayout.addStretch(1);

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
        call(TransientDialog.del, [], me);
    },

    #
    # @return ghost  Canvas layout.
    #
    _drawTopBar: func {
        me._backBtn = canvas.gui.widgets.Button.new(me._group)
            .setText("<")
            .setFixedSize(26, 26)
            .listen("clicked", func {
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

                me._displayRoot();

                if (prev != nil) {
                    me._scrollArea.scrollTo(prev.scrollX, prev.scrollY);
                }
            })
            .setEnabled(false);

        me._refreshBtn = canvas.gui.widgets.Button.new(me._group)
            .setText("R")
            .setFixedSize(26, 26)
            .listen("clicked", func me._displayRoot());

        me._pathLabel = canvas.gui.widgets.Label.new(me._group)
            .setText(me._getPath());

        var hBox = canvas.HBoxLayout.new();
        hBox.addSpacing(me.PADDING);
        hBox.addItem(me._backBtn);
        hBox.addItem(me._refreshBtn);
        hBox.addItem(me._pathLabel);
        hBox.addStretch(1);

        return hBox;
    },

    #
    # @return void
    #
    _displayRoot: func {
        Profiler.start("_displayRoot");

        var widgetsSize = size(me._widgets);
        var index = 0;

        if (ishash(me._items)) {
            foreach (var key; sort(keys(me._items), func(a, b) cmp(me._toLower(a), me._toLower(b)))) {
                if (key == "arg") {
                    continue;
                }

                me._displayItem(index, widgetsSize, key, me._items[key]);
                index += 1;
            }
        } elsif (isvec(me._items)) {
            forindex (var i; me._items) {
                me._displayItem(index, widgetsSize, i, me._items[i]);
                index += 1;
            }
        }

        # Hide rest of widgets
        for (var i = index; i < widgetsSize; i += 1) {
            me._widgets[i].layout.itemAt(1).setVisible(false); # button
            me._widgets[i].layout.setVisible(false);
        }

        Profiler.stop();
    },

    #
    # @param  scalar  scalar
    # @return string Return string converted to lower case letters.
    #
    _toLower: func(scalar) {
           if (isint(scalar)) scalar = sprintf("%d", scalar);
        elsif (isnum(scalar)) scalar = sprintf("%f", scalar);

        return string.lc(scalar);
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

        me._displayRoot();

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

        var val = "";
        if (type == 'hash' and isa(value, props.Node)) {
            val = value.getValue();
            val = val == nil
                ? ", props.Node value = nil"
                : ", props.Node value = " ~ val;
        }

           if (type == 'scalar') return id ~ " = " ~ me._printScalarValue(value);
        elsif (type == 'hash')   return id ~ " = {}" ~ val ~ " (keys: " ~ size(value) ~ ")";
        elsif (type == 'vector') return id ~ " = [] (items: " ~ size(value) ~ ")";
        elsif (type == 'nil')    return id ~ " = nil";
        elsif (type == 'ghost')  return id ~ " = <ghost " ~ ghosttype(value) ~ ">";
        else                     return id ~ " = <" ~ type ~ ">"; # func
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
        var dy = isArrow
            ? 20
            : ScrollAreaHelper.getScrollPageHeight(me._scrollArea);

        if (isUp) {
            dy = -dy;
        }

        me._scrollArea.vertScrollBarBy(dy);
    },
};
