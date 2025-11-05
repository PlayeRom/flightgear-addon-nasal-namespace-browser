#
# This is the second legacy version found in the F-16 source code, as described on Wiki page:
# https://wiki.flightgear.org/Nasal_Browser. To obtain all the functionality, this version required an additional Nasal
# module ("extended-nasal"), which could not be located.
#
# This code has been adopted to work in a modern version of FlightGear. To see how it works, in the
# `/addon-menubar-items.xml` file, uncomment `<item>` for "Legacy Browser 2014" and in the `/addon-main.nas` file,
# uncomment the `/nasal/Legacy/NasalBrowser2014.nas` line in the `hookFilesExcludedFromLoading` function.
#
var NasalBrowser2014 = {
    _dbgLevel: LOG_DEBUG,
    __displayError: true,

    instances: [],

    _typeVal: {
        'hash':   0,
        'vector': 1,
        'func':   2,
        'scalar': 3,
        'ghost':  4,
        'nil':    5,
    },

    styles: {
        'canvas-default': {
            size: [450, 750],
            separate_lines: 1,
            windowStyle: 'dialog',
            padding: 5,
            max_output_chars: 87,
            colors: {
                text: [0.8, 0.86, 0.8],
                text_fill: nil,
                background: [0.8, 0.83, 0.83],
                error: [1, 0.2, 0.1],
                types: {
                    'scalar': [0.4, 0.0, 0.6],
                    'func':   [0.0, 0.0, 0.5],
                    'hash':   [0.9, 0.0, 0.1],
                    'vector': [0.0, 0.7, 0.0],
                    'ghost':  [1.0, 0.3, 0.0],
                    'nil':    [0.2, 0.2, 0.2],
                },
                string_factor: 0.7, # for non-interned, non-number keys the color is reduced
            },
            alignment: 'left-baseline',
            line_height: 1.25,
            font_size: 14,
            font_file: 'LiberationFonts/LiberationSans-Regular.ttf',
            font_aspect_ratio: 1,
            font_max_width: nil,
        },
    },

    new: func(name = 'canvas-nasal-browser', style = 'canvas-default') {
        if (typeof(style) == 'scalar') {
            style = NasalBrowser2014.styles[style];
        }

        if (typeof(style) != 'hash') {
            die('bad style');
        }

        var obj = {
            parents: [
                NasalBrowser2014,
                style,
            ],
            name: name,
            _listeners: [],
            _timer: nil,
            _rootNs: globals,
            _history: [],
            _editMsg: '[shift + click to edit]',
            _editing: nil,
            _editPad: nil,
            _childrenNs: [],
            _elemItems: {},
            subWindow: nil,
            cmp: NasalBrowser2014.cmpName,
            fnArgCache: nil,
            displayFuncArgs: false,
            _updateInterval: 1.0,
        };

        obj._window = canvas.Window.new(style.size, style.windowStyle, obj.name);
        obj._window.set('title', 'Nasal Namespace Browser');
        obj._window.del = func {
            delete(me, 'del');
            me.del(); # inherited canvas.Window.del();
            obj._window = nil;
            obj.del();
        };

        if (obj.windowStyle != nil) {
            obj._window.setBool('resize', 1);
        }

        var myCanvas = obj._window.createCanvas().setColorBackground(obj.colors.background);
        var rootElem = myCanvas.createGroup('content');

        obj._backBtn = canvas.gui.widgets.Button.new(rootElem, canvas.style, {})
            .setText('Back')
            .setEnabled(false);

        obj._backBtn.listen('clicked', func(e) {
            if (!size(obj._history)) {
                return;
            }

            obj._rootNs = pop(obj._history);
            obj._scroll.scrollTo(0, 0);
            obj._editing = nil;
            obj.update();
        });

        obj._refreshBtn = canvas.gui.widgets.Button.new(rootElem, canvas.style, {})
            .setText('Refresh');
        obj._refreshBtn.listen('clicked', func obj.update());

        obj._optionsBtn = canvas.gui.widgets.Button.new(rootElem, canvas.style, {})
            .setText('Options');
        obj._optionsBtn.listen('clicked', func obj._openOptions());

        obj._timingLabel = canvas.gui.widgets.Label.new(rootElem, canvas.style, {})
            .setText('Time taken to refresh: xxx ms');

        obj._scroll = canvas.gui.widgets.ScrollArea.new(rootElem, canvas.style, {});
        obj._scroll.setColorBackground(obj.colors.background);
        obj._scroll.setContentsMargins(10, 5, 2, 0);

        obj._editingLabel = canvas.gui.widgets.Label.new(rootElem, canvas.style, {})
            .setText(obj._editMsg);

        obj._group = obj._scroll.getContent();

        var tabBar = canvas.HBoxLayout.new();
        tabBar.addItem(obj._backBtn);
        tabBar.addItem(obj._refreshBtn);
        tabBar.addItem(obj._optionsBtn);
        tabBar.addItem(obj._timingLabel);
        tabBar.addStretch(1);

        var vbox = canvas.VBoxLayout.new();
        vbox.addItem(tabBar);
        vbox.addItem(obj._scroll, 1);
        vbox.addItem(obj._editingLabel);

        obj._window.setLayout(vbox);

        obj._window.addEventListener('keydown', func(event) {
            obj._handleKey(event);
        });

        if (obj._updateInterval != nil) {
            obj._timer = maketimer(obj._updateInterval, obj, obj.update);
            obj._timer.start();
        }

        obj._searcher = geo.PositionedSearch.new(obj._getChildren, obj._onAdded, obj._onRemoved, obj);
        obj._searcher._equals = func(a, b) a.id == b.id;
        obj.update();

        append(NasalBrowser2014.instances, obj);
        return obj;
    },

    del: func {
        if (me.subWindow != nil) {
            me.subWindow.del();
            me.subWindow = nil;
        }

        if (me._window != nil) {
            me._window.del();
            me._window = nil;
        }

        if (me._timer != nil) {
            me._timer.stop();
            me._timer = nil;
        }

        # Don't remove listeners as FG will do that as we are in the addon namespace.
        # foreach (var l; me._listeners) {
        #     removelistener(l);
        # }

        # setsize(me._listeners, 0);

        forindex (var i; NasalBrowser2014.instances) {
            if (NasalBrowser2014.instances[i] == me) {
                NasalBrowser2014.instances[i] = NasalBrowser2014.instances[-1];
                pop(NasalBrowser2014.instances);
                break;
            }
        }
    },

    # Static method!
    cmpName: func(a, b) {
        return NasalBrowser2014._keyCmp(a.id, b.id);
    },

    # Static method!
    cmpTypeName: func(a, b) {
        return NasalBrowser2014._keyCmp(NasalBrowser2014._typeVal[typeof(a.value)], NasalBrowser2014._typeVal[typeof(b.value)])
            or NasalBrowser2014._keyCmp(a.id, b.id);
    },

    # Static method!
    _keyCmp: func(a, b) {
        if (num(a) == nil) {
            if (num(b) == nil) {
                return cmp(a, b);
            }

            return 1;
        }

        if (num(b) == nil) {
            return -1;
        }

        return a - b;
    },

    _childByKey: func(key) {
        return {
            id: key,
            value: me._rootNs[key],
            parent: me._rootNs,
        };
    },

    _getChildren: func {
        me._childrenNs = [];
        var hasArg = false;

        if (typeof(me._rootNs) == 'hash') {
            foreach (var k; keys(me._rootNs)) {
                if ((!hasArg or k != 'arg') and k != '__gcsave') {
                    append(me._childrenNs, me._childByKey(k));
                    if (k == 'arg') {
                        hasArg = true;
                    }
                }
            }
        } elsif (typeof(me._rootNs) == 'vector') {
            forindex (var k; me._rootNs) {
                append(me._childrenNs, me._childByKey(k));
            }
            # debug.dump(me._childrenNs);
        }

        return me._childrenNs = sort(me._childrenNs, me.cmp);
    },

    _color: func(child) {
        var ret = me.colors.types[typeof(child.value)];

        if (me._role(child.id) == 'string'
            and me.colors.string_factor != nil
            and me.colors.string_factor != 1
        ) {
            forindex (var i; ret ~= []) { # copy color
                ret[i] = math.min(1, me.colors.string_factor * ret[i]);
            }
        }

        return ret;
    },

    _onAdded: func(child) {
        var elem = me._group.createChild('text', 'key ' ~ child.id)
            .setAlignment(me.alignment)
            .setFontSize(me.font_size, me.font_aspect_ratio)
            .setFont(me.font_file)
            .setDouble('line-height', me.line_height);

        elem.addEventListener('click', func(e) {
            delete(caller(0)[0], 'me'); # just in case
            var child = me._latestChild(child);
            me._moveRoot(child, e.shiftKey);
        });

        me._elemItems[child.id] = elem;
    },

    _onRemoved: func(child) me._elemItems[child.id].del(),

    update: func {
        # debug.dump(me.text.getTransformedBounds());
        var time = systime();
        me._searcher.update();
        var spacing = me.line_height * me.font_size;
        var y = -spacing;

        foreach (var child; me._childrenNs) {
            me._elemItems[child.id]
                .setText(me._display(child.id, child.value))
                .setTranslation(0, (y += spacing))
                .setColor(me._color(child));
        }

        me._group.update(); # re-render so scrolling is accurate
        me._scroll.update();

        if (size(me._history)) {
            me._backBtn.setText('Back (' ~ size(me._history) ~ ')').setEnabled(true);
        } else {
            me._backBtn.setText('Back').setEnabled(false);
        }

        if (typeof(me._editing) == 'hash') {
            var key = me._actions[me._role(me._editing.id)](me._editing.id);
            me._editing = me._latestChild(me._editing);
            me._editingLabel.setText('[key ' ~ key ~ ']: me[key]=' ~ me._editPad);
        } elsif (typeof(me._editing) == 'vector') {
            var sz = size(me._editing) - 1;
            if (sz > 9) {
                sz = chr(`a` + sz - 10);
            }

            me._editingLabel.setText('closure 0-' ~ sz ~ '?');
        } else {
            me._editingLabel.setText(me._editMsg);
        }

        time = (systime() - time) * 1000;
        logprint(LOG_DEBUG, 'NasalBrowser.update() took ' ~ int(time) ~ ' ms');
        me._timingLabel.setText('Time taken to refresh: ' ~ int(time) ~ ' ms');
    },

    _latestChild: func(child) {
        # Grab the latest value, not what we have here:
        foreach (var c; me._childrenNs) {
            if (c.id == child.id) {
                return c;
            }
        }

        return child;
    },

    _moveRoot: func {
        if (size(arg)) {
            var child = arg[0];
        }

        if (size(arg) == 1) {
            arg ~= [0];
        }

        if (!size(arg)) {
            if (!size(me._history)) {
                return;
            }

            me._rootNs = pop(me._history);
        } elsif (arg[1]) {
            me._editing = child;
            if (typeof(child.value) == 'scalar') {
                me._editPad = debug.string(child.value, 0);
            } else {
                me._editPad = '';
            }

            me._editMsg = '';

            return me.update();
        } elsif (typeof(child.value) == 'hash' or typeof(child.value) == 'vector') {
            append(me._history, me._rootNs);
            me._rootNs = child.value;
        } elsif (typeof(child.value) == 'func') {
            me._editing = [];
            var lvl = -1;
            while ((var cl = closure(child.value, lvl += 1)) != nil) {
                append(me._editing, cl);
            }

            if (size(me._editing)) {
                me._editPad = nil;
                me._editMsg = '';
                return me.update();
            }
        } else {
            return;
        }

        me._scroll.scrollTo(0, 0);
        me._editing = nil;
        me._editPad = nil;
        me._editMsg = '';
        me.update();
    },

    # Possible fields of event:
    #   event.key - key as name
    #   event.keyCode - key as code
    # Modifiers:
    #   event.shiftKey
    #   event.ctrlKey
    #   event.altKey
    #   event.metaKey
    _handleKey: func(event) {
        if (event.altKey or event.metaKey) {
            return false; # had extra modifiers, reject this event
        }

        if (event.key == 'Escape') {  # escape -> cancel
            logprint(me._dbgLevel, 'esc');
            if (me._editing != nil) {
                me._editPad = me._editing = nil;
                me.update();
            } else {
                me.del();
            }

            return true;

        } elsif (typeof(me._editing) == 'vector') {
            # Take a decimal/hexadecimal/base36 number
               if (event.keyCode >= `0` and event.keyCode <= `9`) var val = event.keyCode - `0`;
            elsif (event.keyCode >= `a` and event.keyCode <= `z`) var val = event.keyCode - `a` + 10;
            elsif (event.keyCode >= `A` and event.keyCode <= `A`) var val = event.keyCode - `A` + 10;
            else return 0;

            var key = {
                value: me._editing[0],
            };
            me._moveRoot(key);

        } elsif (me._editing == nil) {
            return false; # don't care about other events when not editing

        } elsif (event.key == 'Enter') {
            logprint(me._dbgLevel, 'return (key: ' ~ event.keyCode ~ ', shift: ' ~ event.shiftKey ~ ')');
            me._editing = me._latestChild(me._editing);
            me._editMsg = '';
            var c = call(func compile('me[key]=' ~ me._editPad, '<nasal browser editing>'), nil, var err = []);
            if (size(err)) {
                me._editMsg = 'syntax error, see console';
                debug.printerror(err);
            } else {
                bind(c, globals);
                call(c, nil, me._editing.parent, { key: me._editing.id }, err);
                if (size(err)) {
                    me._editMsg = 'runtime error, see console';
                    debug.printerror(err);
                }
            }
            me._editing = nil;
            me._editPad = '';

        } elsif (event.key == 'Backspace') {
            logprint(me._dbgLevel, 'back');
            if (size(me._editPad)) {
                me._editPad = substr(me._editPad, 0, size(me._editPad) - 1);
            }

        } elsif (!string.isprint(event.keyCode)) {
            logprint(me._dbgLevel, 'other key: ' ~ event.keyCode);
            return false;                  # pass other funny events

        } else {
            logprint(me._dbgLevel, 'key: ' ~ event.keyCode ~ ' (`' ~ chr(event.keyCode) ~ '`)');
            me._editPad ~= chr(event.keyCode);
        }

        me.update();
        return true;
    },

    _display: func(key, variable, sep = ' = ') {
        key = me._actions[me._role(key)](key);
        var type = typeof(variable);

        if (type == 'scalar') {
            call(func size(variable), nil, var err = []);
            if (size(err)) {
                return key ~ sep ~ variable;
            }

            return key ~ sep ~ "'" ~ variable ~ "'";
        }

        if (type == 'hash') {
            return key ~ sep ~ '{size ' ~ size(variable) ~ '}/';
        }

        if (type == 'vector') {
            return key ~ sep ~ '[size ' ~ size(variable) ~ ']/';
        }

        if (type == 'nil') {
            return key ~ sep ~ 'nil';
        }

        if (type == 'ghost') {
            return key ~ sep ~ '<ghost/' ~ ghosttype(variable) ~ '>';
        }

        if (type == 'func' and me.displayFuncArgs) {
            var i = id(variable);
            if (me.fnArgCache != nil and contains(me.fnArgCache, i)) {
                return key ~ sep ~ me.fnArgCache[i];
            }

            var ret = call(func {
                var s = func r ? ', ' : '';
                var representation = func(v) {
                    return v == nil
                        ? 'nil'
                        : me._role(v) == 'string'
                            ? debug.string(v, 0)
                            : v;
                }
                var d = debug.decompile(variable);
                var r = '';

                foreach  (var a; d.arg_syms) {
                    r ~= s() ~ a;
                }

                forindex (var i; d.opt_arg_syms) {
                    r ~= s() ~ d.opt_arg_syms[i] ~ '=' ~ representation(d.opt_arg_vals[i]);
                }

                if (d.rest_arg_sym != nil) {
                    r ~= s() ~ d.rest_arg_sym ~ '...';
                }

                return '(' ~ r ~ ')';
            }, nil, var err = []);

            if (size(err) and err[0] == 'decompile argument not a code object!') {
                return key ~ sep ~ '<internal func>';
            }

            if (me.__displayError and size(err)) {
                debug.printerror(err);
                me.__displayError = false;
            }

            if (ret) {
                return key ~ sep ~ (
                    me.fnArgCache != nil
                        ? (me.fnArgCache[i] = '<func' ~ ret ~ '>')
                        : '<func' ~ ret ~ '>'
                );
            }

            return key ~ sep ~ '<func>';
        }

        return key ~ sep ~ '<' ~ type ~ '>';
    },

    _openOptions: func {
        if (me.subWindow != nil) {
            me.subWindow.del();
        }

        me.subWindow = me.OptionsWindow.new(me);
    },

    OptionsWindow: {
        new: func(parent) {
            var obj = {
                parents: [
                    NasalBrowser2014.OptionsWindow,
                ],
                _parent: parent,
            };

            obj._window = canvas.Window.new([300, 300], 'dialog', obj._parent.name ~ '-options');

            obj._window.del = func {
                delete(me, 'del');
                me.del(); # inherited canvas.Window.del();
                obj._window = nil;
                obj.del();
            };

            var myCanvas = obj._window.createCanvas().setColorBackground(obj._parent.colors.background);
            var rootElem = myCanvas.createGroup('root');

            obj._scroll = canvas.gui.widgets.ScrollArea.new(rootElem, canvas.style, {});
            obj._group = obj._scroll.getContent();

            var layout = canvas.HBoxLayout.new();
            layout.addItem(obj._scroll);
            obj._window.setLayout(layout);

            var opts = [];
            append(opts, {
                label: 'Sort by type',
                toggled: func(e) {
                    obj._parent.cmp = e.detail.checked ? obj._parent.cmpTypeName : obj._parent.cmpName;
                    obj._parent._scroll.scrollTo(0, 0);
                    obj._parent.update();
                },
                checked: obj._parent.cmp == obj._parent.cmpTypeName,
            });

            if (contains(globals.debug, 'decompile')) { # requires extended-nasal binary
                append(opts, {
                    label: 'Show function arguments (experimental)',
                    toggled: func(e) {
                        obj._parent.displayFuncArgs = e.detail.checked;
                        obj._parent.update();
                    },
                    checked: obj._parent.displayFuncArgs,
                });

                append(opts, {
                    label: 'Cache function arguments (warning: may leak memory)',
                    toggled: func(e) {
                        obj._parent.fnArgCache = e.detail.checked ? {} : nil;
                        obj._parent.update();
                    },
                    checked: obj._parent.fnArgCache != nil,
                });
            }

            var vbox = canvas.VBoxLayout.new();

            foreach (var opt; opts) {
                var option = canvas.gui.widgets.CheckBox.new(obj._group, canvas.style, { 'wordWrap': true })
                    .setText(opt.label);
                option.setChecked(opt.checked);
                option.listen('toggled', opt.toggled);
                vbox.addItem(option, 0);
            }

            vbox.addStretch(1);

            obj._scroll.setLayout(vbox);

            obj.update();

            return obj;
        },

        update: func {
            me._group.update();
            me._scroll.update();
        },

        del: func {
            if (me._window != nil) {
                me._window.del();
                me._window = nil;
            }

            if (me._parent != nil) {
                me._parent.subWindow = nil;
                me._parent = nil;
            }
        },
    },

    _deniedSymbols: [
        '',
        'func',
        'var',
        'if',
        'else',
        'elsif',
        'for',
        'foreach',
        'forindex',
        'while',
        'nil',
        'break',
        'continue',
        'return',
    ],

    _isSym: func(str) {
        foreach (var d; me._deniedSymbols) {
            if (str == d) {
                return 0;
            }
        }

        var length = size(str);
        var s = str[0];

        if ((s < `a` or s > `z`)
            and (s < `A` or s > `Z`)
            and (s != `_`)
        ) {
            return 0;
        }

        for (var i = 1; i < length; i += 1) {
            if (((s = str[i]) != `_`)
                and (s < `a` or s > `z`)
                and (s < `A` or s > `Z`)
                and (s < `0` or s > `9`)
            ) {
                return 0;
            }
        }

        return 1;
    },

    _internSymbol: func(symbol) {
        assert('argument not a symbol', me._isSym, symbol);

        var getInterned = compile("""
            keys({" ~ symbol ~ ":})[0]
        """);

        return getInterned();
    },

    _isInterned: func(symbol) {
        return (id(symbol) == id(me._internSymbol(symbol)));
    },

    _role: func(a) {
        if (num(a) == nil) {
            if (me._isSym(a) and me._isInterned(a)) {
                return 'symbol';
            }

            return 'string';
        }

        return call(id, [a], []) == nil
            ? 'number'
            : 'string';
    },

    # For displaying a key based on its _role()
    _actions: {
        'symbol': func(key) key,
        'string': func(key) debug.string(key, 0),
        'number': func(key) key,
    },
};
