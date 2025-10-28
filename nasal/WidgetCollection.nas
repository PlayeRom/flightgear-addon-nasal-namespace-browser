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
# Class for handle widgets vector.
#
var WidgetCollection = {
    #
    # Constants:
    #
    LABEL_INDEX: 0,
    BUTTON_INDEX: 1,

    COLOR: {
        DEFAULT: canvas.style.getColor("text_color"),
        RED: [0.8, 0, 0],
    },

    #
    # Constructor.
    #
    # @return void
    #
    new: func() {
        var obj = {
            parents: [
                WidgetCollection,
            ],
        };

        obj._widgets = [];
        obj._foundIndex = nil;

        return obj;
    },

    #
    # @return int
    #
    size: func() {
        return size(me._widgets);
    },

    #
    # @param  ghost  layout  Canvas layout.
    # @param  scalar  id
    # @param  mixed  value
    # @return vector
    #
    addItem: func(layout, id, value) {
        return append(me._widgets, {
            layout: layout,
            childId: id,
            childValue: value,
        });
    },

    #
    # @param  int  index
    # @param  string  label
    # @param  scalar  id
    # @param  mixed  value
    # @param  bool  isClickable
    # @param  bool  isBtnEnable
    # @return void
    #
    updateItem: func(index, label, id, value, isClickable, isBtnEnable) {
        var item = me._widgets[index];

        me.getLabelByLayout(item.layout)
            .setText(label)
            .setColor(me.COLOR.DEFAULT);

        me.getButtonByLayout(item.layout)
            .setVisible(isClickable)
            .setEnabled(isBtnEnable);

        item.layout.setVisible(true);

        item.childId = id;
        item.childValue = value;
    },

    #
    # @param  int  index
    # @return hash
    #
    getItem: func(index) {
        return me._widgets[index];
    },

    #
    # @param  int  index
    # @return ghost  Canvas layout.
    #
    getLayout: func(index) {
        return me.getItem(index).layout;
    },

    #
    # @param  int  index
    # @return ghost  Canvas label widget.
    #
    getLabelByIndex: func(index) {
        return me.getLabelByLayout(me.getLayout(index));
    },

    #
    # @param  ghost  Canvas layout.
    # @return ghost  Canvas label widget.
    #
    getLabelByLayout: func(layout) {
        return layout.itemAt(me.LABEL_INDEX);
    },

    #
    # @param  int  index
    # @return ghost  Canvas button widget.
    #
    getButtonByIndex: func(index) {
        return me.getButtonByLayout(me.getLayout(index));
    },

    #
    # @param  ghost  Canvas layout.
    # @return ghost  Canvas button widget.
    #
    getButtonByLayout: func(layout) {
        return layout.itemAt(me.BUTTON_INDEX);
    },

    #
    # @param  int  index
    # @return vector
    #
    getChildData: func(index) {
        return [
            me._widgets[index].childId,
            me._widgets[index].childValue,
        ];
    },

    #
    # @param  string|nil  serach
    # @return double|nil  Y position of found label widget or nil if not found.
    #
    searchTextInLabel: func(search) {
        var widgetsSize = me.size();

        var i = 0;
        var foundIndexTmp = me._foundIndex;
        if (foundIndexTmp != nil) {
            i = foundIndexTmp + 1;

            if (foundIndexTmp < widgetsSize) {
                # Back color to default
                me.getLabelByIndex(foundIndexTmp).setColor(me.COLOR.DEFAULT);
            }
        }

        me._foundIndex = nil;

        if (search == nil or search == "") {
            return false;
        }

        search = string.lc(search);

        var posY = me._searchInternal(search, i, widgetsSize);

        if (foundIndexTmp != nil and me._foundIndex == nil) {
            # Not found, but the search did not start from the beginning,
            # so the search should be performed again from the beginning.
            posY = me._searchInternal(search, 0, widgetsSize);
        }

        return posY;
    },

    #
    # @param  string  search  Text to search.
    # @param  int  i  Initial index.
    # @param  int  widgetsSize
    # @return double|nil  Y position of found label widget or nil if not found.
    #
    _searchInternal: func(search, i, widgetsSize) {
        for (; i < widgetsSize; i += 1) {
            var layout = me.getLayout(i);
            var label = me.getLabelByLayout(layout);

            # TODO: Use the Label widget method when available (label.getText()):
            var labelText = string.lc(label._view._text.getText());

            if (find(search, labelText) >= 0) {
                if (!layout.isVisible()) {
                    # If the layout is invisible, it means that we have already searched all visible ones,
                    # so we have to exit.
                    return nil;
                }

                var (x, y, w, h) = label.geometry();

                # Set color to red of found label
                label.setColor(me.COLOR.RED);

                me._foundIndex = i;

                return y;
            }
        }

        return nil;
    },
};
