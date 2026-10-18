pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// Settings page, right: the selected category's groups as cards in two
// newspaper columns (wide ones across both), split by their measured
// heights so both end together, or every setting matching the search,
// under its category's name. Acts as the `form` for its SchemaField rows.
Item {
  id: root

  required property var categories
  // The selected entry of `categories`
  required property var category

  readonly property var schema: ConfigManager.configSchema
  readonly property string query: SettingsManager.query.trim().toLowerCase()
  readonly property bool searching: query !== ""

  signal edited(var path, var value)
  onEdited: (path, value) => SettingsManager.setValue(path, value)
  // A text field's keystroke: unsaved at once, applied on its commit
  signal typed(var path, var value)
  onTyped: (path, value) => SettingsManager.setDraftValue(path, value)

  function valueAt(path) {
    let value = SettingsManager.localConfig;
    for (const key of path)
      value = value?.[key];
    return value;
  }

  // Matches English and the translation, so either can be typed
  function _matches(text) {
    return !!text && (text.toLowerCase().includes(root.query) || I18n.tr(text).toLowerCase().includes(root.query));
  }

  // Whether an `x-showIf`-style condition holds, its plain keys being
  // siblings under `parent` (a key path)
  function conditionHolds(condition, parent) {
    return SchemaLayout.showIfHolds(condition, key => key.startsWith("/") ? SettingsManager.configValueAt(key.slice(1)) : root.valueAt(parent.concat(key)));
  }

  // A card from an object with `x-showIf` (e.g. managed-only settings), or
  // one whose every row is hidden by its own `x-showIf` (an `x-group` card)
  function _groupShown(group) {
    if (!root.conditionHolds(group.showIf, group.showIfParent))
      return false;
    return group.kind !== "rows" || group.rows.length === 0 || group.rows.some(row => row.kind === "group" || root.conditionHolds(row.schema?.["x-showIf"], row.path.slice(0, -1)));
  }

  function _rowMatches(row) {
    return row.kind !== "group" && (_matches(row.title) || _matches(row.schema?.description) || row.path[row.path.length - 1].toLowerCase().includes(root.query));
  }

  // From the schema, category and search only: never from config values,
  // so editing doesn't rebuild the cards. Search results carry their
  // category's name
  readonly property var groups: {
    if (!root.searching)
      return SchemaLayout.categoryGroups(root.schema, root.category);
    // Hand-built cards have no rows to search
    return [].concat(...root.categories.map(category => SchemaLayout.categoryGroups(root.schema, category).filter(group => group.kind !== "card").map(group => {
        const rows = root._matches(group.title) || root._matches(group.section) ? group.rows : group.rows.filter(row => root._rowMatches(row));
        return rows.length > 0 ? Object.assign({}, group, {
          "rows": rows,
          "category": category.name,
          "categoryIcon": category.icon
        }) : null;
      }).filter(group => group !== null)));
  }

  // Which groups are shown, as a string so it only notifies when that
  // actually changes, not on every edit
  readonly property string _shownKey: root.groups.map(group => root._groupShown(group) ? "1" : "0").join("")

  // The selected category's shown cards, for the sidebar to jump to
  readonly property var shownGroups: {
    if (root.searching)
      return [];
    const shown = root._shownKey;
    return root.groups.filter((group, i) => shown[i] === "1");
  }

  // The shown cards that can fold (hand-built ones only with `x-cardFolds`,
  // and none while searching)
  readonly property var foldableKeys: {
    if (root.searching)
      return [];
    const shown = root._shownKey;
    return root.groups.filter((group, i) => shown[i] === "1" && (group.kind === "rows" || group.folds)).map(group => group.key);
  }
  readonly property bool allFolded: root.foldableKeys.length > 0 && root.foldableKeys.every(key => SettingsManager.isCollapsed(key))

  // Lays the columns out again once the cards have folded. Folding one
  // card doesn't, so it never moves the cards across columns
  signal relayout

  function setAllFolded(value) {
    SettingsManager.setCollapsed(root.foldableKeys, value);
    root.relayout();
  }

  // The shown groups in two columns: one block per category while
  // searching (`name`, its heading), else one for the selected category
  readonly property var blocks: {
    const shown = root._shownKey;
    const blocks = [];
    root.groups.forEach((group, i) => {
      if (shown[i] !== "1")
        return;
      const name = group.category ?? "";
      if (blocks.length === 0 || blocks[blocks.length - 1].name !== name)
        blocks.push({
          "name": name,
          "icon": group.categoryIcon ?? "",
          "groups": []
        });
      blocks[blocks.length - 1].groups.push(group);
    });
    return blocks;
  }

  // The card each group key is drawn by, to scroll to
  property var _cards: ({})

  Connections {
    target: SettingsManager
    function onJumpRequested(key, unfolded) {
      jumpDelay.key = key;
      jumpDelay.interval = unfolded ? Appearance.animNormal : 0;
      jumpDelay.restart();
    }
  }

  // Waits for an unfolding card to open, so the page is long enough to
  // bring it to the top
  Timer {
    id: jumpDelay
    property string key
    onTriggered: {
      const card = root._cards[jumpDelay.key];
      if (!card)
        return;
      titledCard.scrollTo(card);
      card.flash();
    }
  }

  // Pages the category links to: the pinned layouts editor always exists,
  // others only while they're in Overlay.views
  function _linkAvailable(type) {
    return type === "Layouts" || OverlayConfig.views.some(view => view.type === type && view.visible !== false);
  }

  readonly property var links: root.searching ? [] : (root.category?.links ?? []).filter(type => root._linkAvailable(type))

  // The category's place in the sidebar (-1 while searching): a new one
  // slides in from the side of the list it was picked from
  readonly property int _pageIndex: root.searching ? -1 : root.categories.indexOf(root.category)
  property int _lastPageIndex: -1

  Component.onCompleted: root._lastPageIndex = root._pageIndex
  on_PageIndexChanged: {
    slide.from = (root._pageIndex > root._lastPageIndex ? 1 : -1) * Widget.spacing * 4;
    root._lastPageIndex = root._pageIndex;
    pageIn.restart();
  }

  ParallelAnimation {
    id: pageIn

    NumberAnimation {
      id: slide
      target: pageShift
      property: "y"
      to: 0
      duration: Appearance.animNormal
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: pageBody
      property: "opacity"
      from: 0
      to: 1
      duration: Appearance.animNormal
      easing.type: Easing.OutCubic
    }
  }

  TitledCard {
    id: titledCard
    // I18n.tr("Search results"); category names come from the schema's
    // x-categories
    title: root.searching ? I18n.tr("Search results") : (root.category ? I18n.tr(root.category.name) : "")
    dirty: SettingsManager.isDirty
    onSave: SettingsManager.saveChanges()
    onReset: SettingsManager.resetChanges()

    // Fold all on the left, links to other pages on the right
    showExtras: root.links.length > 0 || root.foldableKeys.length > 0
    headerExtras: RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledTextButton {
        visible: root.foldableKeys.length > 0
        Layout.preferredHeight: Widget.height - 4
        text: root.allFolded ? I18n.tr("Unfold all") : I18n.tr("Fold all")
        iconText: root.allFolded ? "unfold_more" : "unfold_less"
        onClicked: root.setAllFolded(!root.allFolded)
      }

      Item {
        Layout.fillWidth: true
      }

      StyledText {
        visible: root.links.length > 0
        text: I18n.tr("More in")
        opacity: 0.6
      }

      Repeater {
        model: root.links

        delegate: StyledTextButton {
          required property string modelData
          Layout.preferredHeight: Widget.height - 4
          text: OverlayConfig.viewLabel({
            "type": modelData
          }, 0)
          iconText: OverlayConfig.viewIcon(modelData)
          onClicked: ShellManager.showOverlayPage(modelData)
        }
      }
    }

    // The page, which moves as one when it changes
    ColumnLayout {
      id: pageBody
      Layout.fillWidth: true
      spacing: Widget.spacing * 2
      transform: Translate {
        id: pageShift
      }

      StyledText {
        visible: root.searching && root.groups.length === 0
        text: I18n.tr("No settings match \"{0}\"", SettingsManager.query)
        opacity: 0.6
        Layout.fillWidth: true
        Layout.topMargin: Widget.padding
      }

      Repeater {
        model: root.blocks

        delegate: ColumnLayout {
          id: block
          required property var modelData
          Layout.fillWidth: true
          spacing: Widget.spacing

          readonly property real gap: Widget.spacing * 2
          // Each card's measured height, by index
          property var heights: block.modelData.groups.map(() => 0)
          // Which cards span both columns (from the schema only)
          readonly property var wide: block.modelData.groups.map(group => group.wide === true)
          // Each run's split, between the wide cards
          property var splits: []
          property bool settling: true
          readonly property var placed: ColumnSplit.place(block.heights, block.wide, block.splits, block.gap)

          function setHeight(i, height) {
            if (block.heights[i] === height)
              return;
            const next = block.heights.slice();
            next[i] = height;
            block.heights = next;
            if (block.settling) {
              block.splits = ColumnSplit.splits(next, block.wide, block.gap);
              settle.restart();
            }
          }

          function relayout() {
            block.settling = true;
            block.splits = ColumnSplit.splits(block.heights, block.wide, block.gap);
            settle.restart();
          }

          // Fixes `splits` once the heights stop changing (cards loading or
          // folding): a quiet spell, restarted by every change, so not an
          // animation duration (which is 0 with motion off)
          Timer {
            id: settle
            interval: 150
            running: true
            onTriggered: block.settling = false
          }

          Connections {
            target: root
            function onRelayout() {
              block.relayout();
            }
          }

          // A search result's category: its icon and name, then a rule.
          // Names come from the schema's x-categories
          RowLayout {
            visible: block.modelData.name !== ""
            Layout.fillWidth: true
            Layout.topMargin: Widget.spacing
            spacing: Widget.spacing

            StyledIcon {
              text: block.modelData.icon
              textColor: Theme.accent
            }

            StyledText {
              text: I18n.tr(block.modelData.name)
              textSize: Appearance.fontSize + 2
              font.bold: true
            }

            StyledSeparator {
              Layout.fillWidth: true
              separatorHeight: 1
              opacity: 0.3
            }
          }

          // The block's cards, each run between wide ones split in two
          // columns. Positions follow the cards' heights live; `splits`
          // follow them only while `settling` (after a build, a resize or
          // fold all)
          Item {
            id: cards
            Layout.fillWidth: true
            implicitHeight: block.placed.height
            onWidthChanged: block.relayout()

            Repeater {
              model: block.modelData.groups

              // A hand-built card (`x-card`: settings/<name>Card.qml) or rows
              delegate: Loader {
                id: card
                required property var modelData
                required property int index
                readonly property var place: block.placed.cards[card.index] ?? ({
                    "column": 0,
                    "y": 0
                  })
                readonly property real halfWidth: (cards.width - block.gap) / 2
                width: card.place.column === -1 ? cards.width : card.halfWidth
                x: card.place.column === 1 ? card.halfWidth + block.gap : 0
                y: card.place.y
                onImplicitHeightChanged: block.setHeight(card.index, card.implicitHeight)
                Component.onCompleted: {
                  if (!root.searching)
                    root._cards[card.modelData.key] = card;
                  // Its title from the schema (`x-cardTitle`, or the
                  // category's `cardTitle`), as the sidebar names it
                  if (card.modelData.kind === "card")
                    card.setSource(Qt.resolvedUrl(card.modelData.card + "Card.qml"), Object.assign({
                      "title": I18n.tr(card.modelData.title)
                    }, card.modelData.folds ? {
                      "foldKey": card.modelData.key
                    } : {}));
                  else
                    card.sourceComponent = rowsCard;
                  block.setHeight(card.index, card.implicitHeight);
                }
                Component.onDestruction: {
                  if (root._cards[card.modelData.key] === card)
                    delete root._cards[card.modelData.key];
                }

                // Outlines the card for a moment (jumped to from the
                // sidebar)
                function flash() {
                  flashAnimation.restart();
                }

                Rectangle {
                  id: outline
                  anchors.fill: parent
                  z: 1
                  radius: Widget.radius
                  color: "transparent"
                  border.color: Theme.accent
                  border.width: Appearance.borderWidth + 1
                  opacity: 0
                }

                SequentialAnimation {
                  id: flashAnimation
                  NumberAnimation {
                    target: outline
                    property: "opacity"
                    to: 1
                    duration: Appearance.animFast
                  }
                  PauseAnimation {
                    duration: Appearance.animSlow
                  }
                  NumberAnimation {
                    target: outline
                    property: "opacity"
                    to: 0
                    duration: Appearance.animSlow
                  }
                }

                Component {
                  id: rowsCard
                  SettingsGroupCard {
                    group: card.modelData
                    form: root
                    showSection: root.searching
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
