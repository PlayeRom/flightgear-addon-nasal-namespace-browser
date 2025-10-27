# Legacy version of Nasal Browser. Written by "Philosopher'.
# https://web.archive.org/web/20210726130630/http://codepad.org/14koLKeg

var NasalBrowserV1 = {
    _browser: nil,

    _makeWindow: func {
        me._browser = canvas.Window.new([400, 600]);
        me._browser.root = globals;
        me._browser.scroll = 0;
        me._browser.history = [];

        var my_canvas = me._browser
            .createCanvas()
            .setColorBackground(0, 0, 0, 0);

        var root = my_canvas.createGroup();
        # Title bar:
        var title_bar = root.createChild("group");
        title_bar.addEventListener("drag", func(e) {
            me._browser.move(e.deltaX, e.deltaY);
        });

        var x = 0;
        var y = 0;
        var rx = 8;
        var ry = 8;
        var w = 400;
        var h = 20;

        title_bar.createChild("path")
            .moveTo(x + w - rx, y)
            .arcSmallCWTo(rx, ry, 0, x + w, y + ry)
            .vertTo(y + h)
            .horizTo(x)
            .vertTo(y + ry)
            .arcSmallCWTo(rx, ry, 0, x + rx, y)
            .close()
            .setColorFill(0.25, 0.24, 0.22)
            .setStrokeLineWidth(0)
            .addEventListener("click", func {
                gui.popupTip("Back");

                me._browser.root = pop(me._browser.history);
                if (!size(me._browser.history)) {
                    append(me._browser.history, globals);
                }

                me._browser.scroll = 0;
                displayRoot();
            });

        # Border/background
        x = 0;
        y = 20;
        w = 400;
        h = 580;

        root.createChild("path")
            .moveTo(x + w, y)
            .vertTo(y + h)
            .horizTo(x)
            .vertTo(y)
            .setColorFill(1, 1, 1)
            .setColor(0, 0, 0);

        # Red-X: close this dialog
        x = 8;
        y = 5;
        w = 10;
        h = 10;

        title_bar.createChild("path", "icon-close")
            .moveTo(x, y)
            .lineTo(x + w, y + h)
            .moveTo(x + w, y)
            .lineTo(x, y + h)
            .setColor(1, 0, 0)
            .setStrokeLineWidth(3)
            .addEventListener("click", func me.removeWindow());

        # Title of this dialog
        title_bar.createChild("text", "dialog-caption")
            .setText("Nasal namespace browser")
            .setTranslation(x + w + 8, 4)
            .setAlignment("left-top")
            .setFontSize(14)
            .setFont("LiberationFonts/LiberationSans-Bold.ttf")
            .setColor(1, 1, 1);

        var body = root.createChild("group");
        body.addEventListener("click", func(e) {
            var y = e.clientY - 20 + me._browser.scroll;
            y /= 16;
            var clicked = me._browser.children[y];
            gui.popupTip("Clicked on " ~ clicked.id);
            clicked = clicked.value;
            if (typeof(clicked) == 'hash' or typeof(clicked) == 'vector') {
                append(me._browser.history, me._browser.root);
                me._browser.root = clicked;
                me._browser.scroll = 0;
            }
            displayRoot();
        });

        body.addEventListener("drag", func(e) {
            me._browser.scroll += e.deltaY;
            me._browser.scroll = me._browser.scroll < 0
                ? 0
                : me._browser.scroll > (size(me._browser.children) - 8) * 16
                    ? math.max((size(me._browser.children) - 8) * 16, 0)
                    : me._browser.scroll;
            displayRoot();
        });

        var display = func(k, variable, sep = " = ") {
            var t = typeof(variable);
            if (t == 'scalar') {
                k ~ sep ~ "'" ~ variable ~ "'";
            } elsif (t == 'hash' or t == 'vector') {
                k ~ "/ (size: " ~ size(variable) ~ ")";
            } elsif (t == 'nil') {
                k ~ sep ~ "nil";
            } else {
                k ~ sep ~ "<" ~ t ~ ">";
            }
        };

        var updateChildren = func() {
            me._browser.children = [];
            var x = 4;
            var y = 34 - 16;

            if (typeof(me._browser.root) == 'hash') {
                foreach (var k; sort(keys(me._browser.root), cmp)) {
                    if (k == "arg") {
                        continue;
                    }

                    append(me._browser.children, {
                        id: k,
                        value: me._browser.root[k],
                        x: x,
                        y: (y += 16),
                    });
                }
            } elsif (typeof(me._browser.root) == 'vector') {
                forindex (var k; me._browser.root) {
                    append(me._browser.children, {
                        id: k,
                        value: me._browser.root[k],
                        x: x,
                        y: (y += 16),
                    });
                }
            }
        };

        var displayRoot = func() {
            updateChildren();
            body.removeAllChildren();
            foreach (var child; me._browser.children) {
                var composite = child.y - me._browser.scroll;
                if (composite > 32 and composite < 575) {
                    body.createChild("text")
                        .setText(display(child.id, child.value))
                        .setTranslation(child.x, composite)
                        .setAlignment("left-baseline")
                        .setFontSize(14)
                        .setFont("LiberationFonts/LiberationSans-Bold.ttf")
                        .setColor(0, 0, 0);
                }
            }
            body.update();
        };

        displayRoot();

        me._browser.addEventListener("keydown", func(event) {
            if (event.key == 'Escape' and !event.shiftKey) {
                me.removeWindow();
            }
        });
    },

    toggleWindow: func {
        if (me._browser != nil) {
            me.removeWindow();
        } else {
            me._makeWindow();
        }
    },

    removeWindow: func {
        if (me._browser) {
            me._browser.del();
            me._browser = nil;
        }
    },
};
