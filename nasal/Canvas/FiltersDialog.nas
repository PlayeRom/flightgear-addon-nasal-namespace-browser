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
# FiltersDialog dialog class.
#
var FiltersDialog = {
    #
    # Constants:
    #
    PADDING: 10,

    TYPES: [
        "func",
        "ghost",
        "hash",
        "nil",
        "scalar",
        "vector",
    ],

    #
    # Constructor.
    #
    # @return hash
    #
    new: func {
        var obj = {
            parents: [
                FiltersDialog,
                TransientDialog.new(
                    width : 210,
                    height: 340,
                    title : "Nasal Browser Filters",
                    resize: false,
                ),
            ],
        };

        obj._nodes = {};
        obj._checkboxes = {};

        obj._addonNodePath = g_Addon.node.getPath();

        foreach (var type; me.TYPES) {
            obj._nodes[type] = props.globals.getNode(obj._addonNodePath ~ "/filters/" ~ type);
        }

        obj._optionSortByType = props.globals.getNode(obj._addonNodePath ~ "/options/sort-by-type");

        obj._buildLayout();

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
    # @return void
    #
    _buildLayout: func() {
        var label = canvas.gui.widgets.Label.new(parent: me._group, cfg: { wordWrap: true })
            .setText("Select which elements should be displayed");

        me._vbox.setContentsMargin(me.PADDING);
        me._vbox.addItem(label);
        me._vbox.addSpacing(me.PADDING);

        foreach (var type; me.TYPES) {
            me._vbox.addItem(me._buildCheckboxRow(type));
        }

        me._vbox.addItem(me._getButton("Select all", func {
            foreach (var type; me.TYPES) {
                me._nodes[type].setBoolValue(true);
                me._checkboxes[type].setChecked(true);
            }
        }));

        me._checkboxSortyByType = me._getCheckbox('Sorty by type', me._optionSortByType);

        me._vbox.addSpacing(me.PADDING);
        me._vbox.addItem(canvas.gui.widgets.HorizontalRule.new(me._group));
        me._vbox.addSpacing(me.PADDING);
        me._vbox.addItem(me._checkboxSortyByType);

        me._vbox.addStretch(1);
    },

    #
    # @param  string  type
    # @return ghost  Horizontal box layout.
    #
    _buildCheckboxRow: func(type) {
        me._checkboxes[type] = me._getCheckbox(type, me._nodes[type]);

        var btn = me._getButton("Only " ~ type)
            .setFixedSize(90, 26);

        func {
            var tmpType = type;
            btn.listen("clicked", func {
                foreach (var subType; me.TYPES) {
                    var isSelected = subType == tmpType;
                    me._nodes[subType].setBoolValue(isSelected);
                    me._checkboxes[subType].setChecked(isSelected);
                }
            });
        }();

        var hBox = canvas.HBoxLayout.new();
        hBox.addItem(me._checkboxes[type]);
        hBox.addItem(btn);

        return hBox;
    },

    #
    # @param  string  label
    # @param  hash  node  Node with filter value.
    # @return ghost  CheckBox widget.
    #
    _getCheckbox: func(label, node) {
        return canvas.gui.widgets.CheckBox.new(me._group)
            .setText(label)
            .setChecked(node.getBoolValue())
            .listen("toggled", func(e) {
                node.setBoolValue(e.detail.checked ? true : false);
            });
    },

    #
    # @param  string  label
    # @param  func  callback
    # @return ghost  Button widget.
    #
    _getButton: func(label, callback = func) {
        return canvas.gui.widgets.Button.new(me._group)
            .setText(label)
            .listen("clicked", callback);
    },
};
