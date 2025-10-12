# Legacy version of Nasal Browser. Written by "Philosopher'.

var browser = nil;

var makeWindow = func {
    browser = canvas.Window.new([400, 600]);
    browser.root = globals;
    browser.scroll = 0;
    browser.history = [];

    var my_canvas = browser
        .createCanvas()
        .setColorBackground(0, 0, 0, 0);

    var root = my_canvas.createGroup();
    # Title bar:
    var title_bar = root.createChild("group");
    title_bar.addEventListener("drag", func(e) {
        browser.move(e.deltaX, e.deltaY);
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

            browser.root = pop(browser.history);
            if (!size(browser.history)) {
                append(browser.history, globals);
            }

            browser.scroll = 0;
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
        .addEventListener("click", func removeWindow());

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
        var y = e.clientY - 20 + browser.scroll;
        y /= 16;
        var clicked = browser.children[y];
        gui.popupTip("Clicked on " ~ clicked.id);
        clicked = clicked.value;
        if (typeof(clicked) == 'hash' or typeof(clicked) == 'vector') {
            append(browser.history, browser.root);
            browser.root = clicked;
            browser.scroll = 0;
        }
        displayRoot();
    });

    body.addEventListener("drag", func(e) {
        browser.scroll += e.deltaY;
        browser.scroll = browser.scroll < 0
            ? 0
            : browser.scroll > (size(browser.children) - 8) * 16
                ? math.max((size(browser.children) - 8) * 16, 0)
                : browser.scroll;
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
        browser.children = [];
        var x = 4;
        var y = 34 - 16;

        if (typeof(browser.root) == 'hash') {
            foreach (var k; sort(keys(browser.root), cmp)) {
                if (k == "arg") {
                    continue;
                }

                append(browser.children, {
                    id: k,
                    value: browser.root[k],
                    x: x,
                    y: (y += 16),
                });
            }
        } elsif (typeof(browser.root) == 'vector') {
            forindex (var k; browser.root) {
                append(browser.children, {
                    id: k,
                    value: browser.root[k],
                    x: x,
                    y: (y += 16),
                });
            }
        }
    };

    var displayRoot = func() {
        updateChildren();
        body.removeAllChildren();
        foreach (var child; browser.children) {
            var composite = child.y - browser.scroll;
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

    browser.listener = setlistener("/devices/status/keyboard/event", func(event) {
        if (!event.getNode("pressed").getValue()) {
            return;
        }

        var key = event.getNode("key");
        var shift = event.getNode("modifier/shift").getValue();
        if (key.getValue() == 27 and !shift) {
            removeWindow();
            key.setValue(-1);           # drop key event
        }
    });
};

var toggleWindow = func {
    if (browser != nil) {
        removeWindow();
    } else {
        makeWindow();
    }
};

var removeWindow = func {
    removelistener(browser.listener);
    browser.del();
    browser = nil;
};
