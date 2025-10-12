Nasal Namespace Browser
=======================

Reimplementation of the [Nasal Browser](https://wiki.flightgear.org/Nasal_Browser) using Canvas Widgets.
This addon is inspired by the original implementation, which appears to have been lost after the shutdown of Gitorious — I was able to locate what seems to be an old copy, now placed in `/nasal/Legacy/NasalBrowser.nas`.

While it retains the spirit and functionality of the original browser, the codebase has been refactored to use the current FlightGear Canvas UI.

## Installation

Installation is standard:

1. Download source code of add-on and unzip it.

2. In Launcher go to "Add-ons" tab. Click "Add" button by "Add-on Module folders" section and select folder with unzipped add-on directory (or add command line option: `--addon=/path/to/nasal-browser`), and click "Fly!".

## Navigation

On the top bar:

- `[<]` - back button, returns to the previous namespace.
- `[R]` - refresh button, refreshes the current namespace.

On the list:

- `[>]` - "go inside" button, if the item is a hash or vector, and has more keys/elements than 0, we can see what's inside.

## Keys

- `Up`/`Down` – scroll content with small increments.
- `PageUp`/`PageDown` – scroll the content by one visible screen.
- `Esc` – close the window.
