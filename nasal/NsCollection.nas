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
# Class for handle namespace collection and history.
#
var NsCollection = {
    #
    # Constructor.
    #
    # @param  hash  filters  Filters object.
    # @return hash
    #
    new: func(filters) {
        var obj = {
            parents: [
                NsCollection,
            ],
            _filters: filters,
        };

        obj._items = globals;
        obj._history = [];

        return obj;
    },

    #
    # Push items to history.
    #
    # @param  vector  scrollPos  Scroll area position x and y.
    # @return void
    #
    pushHistory: func(scrollPos, newItems) {
        append(me._history, {
            item: me._items,
            scrollX: scrollPos[0],
            scrollY: scrollPos[1],
        });

        me._items = newItems;
    },

    #
    # Pop last items from history.
    #
    # @return hash|nil  Removed element from history or nil if history was empty.
    #
    popHistory: func() {
        var prev = nil;
        if (size(me._history)) {
            prev = pop(me._history);
        }

        me._resetItems(prev);

        return prev;
    },

    #
    # @return int
    #
    getHistorySize: func() {
        return size(me._history);
    },

    #
    # @return vector  Array of {key, value} items allowed by filters and sorted.
    #
    getSortedChildren: func() {
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
            if ((key == "arg" and hasArg) or !me._filters.isAllowed(me._items[key])) {
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
            if (!me._filters.isAllowed(me._items[i])) {
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
        if (me._filters.isSortByType()) {
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
    # @param  hash|nil  Last history element or nil.
    # @return void
    #
    _resetItems: func(prev) {
        if (prev != nil and size(me._history)) {
            me._items = prev.item;
            return;
        }

        me._items = globals;
    },
};
