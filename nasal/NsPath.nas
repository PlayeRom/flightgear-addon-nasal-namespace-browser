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
# Class for handle namespace path.
#
var NsPath = {
    #
    # Constructor.
    #
    # @return hash
    #
    new: func() {
        var obj = {
            parents: [
                NsPath,
            ],
        };

        obj._path = [];

        obj.reset();

        return obj;
    },

    #
    # Push new element to path.
    #
    # @param  string  name  Namespace.
    # @param  string  type  Type of new element.
    # @return vector
    #
    push: func(name, type) {
        return append(me._path, {
            name: name,
            type: type,
        });
    },

    #
    # Remove last element from path.
    #
    # @return hash  Removed element.
    #
    pop: func() {
        return pop(me._path);
    },

    #
    # Get path as string.
    #
    # @return string
    #
    get: func {
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
    reset: func {
        me._path = [{
            name: "globals",
            type: "hash",
        }];
    },
};
