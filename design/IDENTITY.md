# The keel

The app's identity is one mark, used at every scale: a **3px bar laid along the edge of
the thing it describes**. It is called the keel because it sits at the bottom/left edge of
a surface and says whether that surface is doing something.

Nothing else in the window is allowed to be accented. Colour appears only where something is
true — focus, loading, selected, blocked, insecure.

## The rules

1. **The keel is the only state mark.** Selected, loading, focused and blocked are all shown
   by lighting a keel. Never a ring around four sides, never a colour wash on its own,
   never an icon swap.
2. **A keel with no state is still there**, in the hairline colour. Edges never appear or
   vanish, so nothing in the chrome flickers when a page finishes loading.
3. **Groups are separated by 1px ticks, not plates.** No control sits inside a rounded
   rectangle of its own; a cluster is a keel plus a couple of rules.
4. **Corners are cut, not pillowed.** Every surface keeps three soft corners and one tight
   one, and the tight corner points at whatever the surface belongs to — a field faces the
   page under it, a menu points back at the button it dropped from, a tab is square where it
   meets the page and round where it meets the bar.
5. **One hairline between chrome and page; shadows only for things that float.** Chrome is
   flat and stacked (`chrome → surface → surfaceAlt`). A shadow means "this is above the
   window": menus, dialogs, the command palette. That is all.
6. **Rows are ticked, not ruled.** A list uses a 16px leading tick instead of a full-width
   divider, and the selected row carries the keel.
7. **Type is left-aligned and set tight.** Masthead 40/800 at -0.8 tracking, title 15.5,
   body 13.5, caption 12.5. Tabular figures everywhere a number can change while you watch.
   Sentence case; no all-caps micro-labels.
8. **Motion is short and only on values we control.** 110ms for hover, 180ms for state,
   260ms for arrival. A back-out curve is allowed on a keel or a tab, never on text.
   Lists arrive in a 14ms cascade, capped at six rows deep.

## Where the mark appears

| Surface | The keel means |
| --- | --- |
| Left edge of the window | the page is loading; the bar fills with the load estimate. Red at the top for a plain `http` page. |
| Leading edge of a tab | this is the tab you are on — in the group colour when the tab is grouped. |
| Left corner of the address plate | the shield is holding something back on this page. |
| Leading edge of a list row | this row is the one the window is showing, or the one the arrow keys are on. |
| Under a selected icon well | this panel is open. |
| Before a title | every heading, in every panel, on every page. |
| Along the focused field | the field has the keyboard, without a ring around it. |

## Numbers

```
bar height        56        keel width        3       radius (control)  9
tab height        42        stub width       32       radius (field)   11
dock inset        12        row minHeight    52       radius (menu)    13
bookmark bar      34        row dense        40       radius (card)    15
                                                  radius (sheet)   19
cut amount        0.28 × radius                 hairline          1
```

Tokens live in `lib/core/ui.dart` (`Ui.keel`, `Ui.tick`, `Ui.hang`, `Ui.petal`, `Ui.lift`,
`Ui.slate`, `Ui.masthead`, `Ui.eyebrow`, `Ui.enter`, `Ui.settle`). Shared widgets in
`lib/widgets/ui_kit.dart` draw the keel themselves, so a page that uses `UiRow`,
`UiSection`, `UiChip` or `UiIconButton` inherits the identity without asking.

The palette is deliberately not part of the identity: navy and cyan stay exactly as they
are, in every theme, and `design/index.html` (built by `tool/build_design_preview.py`)
renders the same numbers from the same source files.

## What this rules out

Yellow/black overflow stripes, plates behind control groups, pill-shaped tabs, a horizontal
progress line under the bar on desktop (the window keel is the progress line), rings around
focused fields, full-width dividers in short lists, centred mastheads, all-caps label rows,
developer vocabulary ("render", "buffer", "command", "mode"), and emoji — icons are the
authored SVG set in `assets/icons/`.
