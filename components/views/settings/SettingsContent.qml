pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// Settings page, right: the selected category's groups as cards in two
// newspaper columns, split by their measured heights so both end together
// (then its hand-built `page`, if any), or every setting matching the
// search, under its category's name. Acts as the `form` for its SchemaField
// rows.
Item {
  id: root

  required property var categories
  // The selected entry of `categories`
  required property var category

  readonly property var schema: ConfigManager.configSchema
  readonly property string query: SettingsManager.query.trim().toLowerCase()
  readonly property bool searching: query !== ""
  // The category's hand-built part (settings/<page>.qml), after its cards
  readonly property string page: root.searching ? "" : root.category?.page ?? ""

  signal edited(var path, var value)
  onEdited: (path, value) => SettingsManager.setValue(path, value)

  function valueAt(path) {
    let value = SettingsManager.localConfig;
    for (const key of path)
      value = value?.[key];
    return value;
  }

  function _groupsOf(category) {
    return [].concat(...(category?.sections ?? []).map(section => SchemaLayout.groups(root.schema, section)));
  }

  // Matches English and the translation, so either can be typed
  function _matches(text) {
    return !!text && (text.toLowerCase().includes(root.query) || I18n.tr(text).toLowerCase().includes(root.query));
  }

  // A card from an object with `x-showIf` (e.g. managed-only settings), or
  // one whose every row is hidden by its own `x-showIf` (an `x-group` card)
  function _groupShown(group) {
    const valueIn = parent => key => key.startsWith("/") ? SettingsManager.configValueAt(key.slice(1)) : root.valueAt(parent.concat(key));
    if (!SchemaLayout.showIfHolds(group.showIf, valueIn(group.showIfParent)))
      return false;
    return group.kind !== "rows" || group.rows.length === 0 || group.rows.some(row => row.kind === "group" || SchemaLayout.showIfHolds(row.schema?.["x-showIf"], valueIn(row.path.slice(0, -1))));
  }

  function _rowMatches(row) {
    return row.kind !== "group" && (_matches(row.title) || _matches(row.schema?.description) || row.path[row.path.length - 1].toLowerCase().includes(root.query));
  }

  // From the schema, category and search only: never from config values,
  // so editing doesn't rebuild the cards. Search results carry their
  // category's name
  readonly property var groups: {
    if (!root.searching)
      return root._groupsOf(root.category);
    // Hand-built cards have no rows to search
    return [].concat(...root.categories.map(category => root._groupsOf(category).filter(group => group.kind !== "card").map(group => {
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
          property int split: 0
          property bool settling: true
          readonly property var tops: ColumnSplit.tops(block.heights, block.split, block.gap)

          function setHeight(i, height) {
            if (block.heights[i] === height)
              return;
            const next = block.heights.slice();
            next[i] = height;
            block.heights = next;
            if (block.settling) {
              block.split = ColumnSplit.split(next, block.gap);
              settle.restart();
            }
          }

          function relayout() {
            block.settling = true;
            block.split = ColumnSplit.split(block.heights, block.gap);
            settle.restart();
          }

          // Fixes `split` once the heights stop changing (cards loading or
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

          // The block's cards, the first `split` on the left. Positions
          // follow the cards' heights live; `split` follows them only while
          // `settling` (after a build, a resize or fold all)
          Item {
            id: cards
            Layout.fillWidth: true
            implicitHeight: ColumnSplit.height(block.heights, block.split, block.gap)
            onWidthChanged: block.relayout()

            Repeater {
              model: block.modelData.groups

              // A hand-built card (`x-card`: settings/<name>Card.qml) or rows
              delegate: Loader {
                id: card
                required property var modelData
                required property int index
                width: (cards.width - block.gap) / 2
                x: card.index < block.split ? 0 : card.width + block.gap
                y: block.tops[card.index] ?? 0
                onImplicitHeightChanged: block.setHeight(card.index, card.implicitHeight)
                Component.onCompleted: {
                  if (!root.searching)
                    root._cards[card.modelData.key] = card;
                  if (card.modelData.kind === "card")
                    card.setSource(Qt.resolvedUrl(card.modelData.card + "Card.qml"), card.modelData.folds ? {
                      "foldKey": card.modelData.key
                    } : {});
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

      // The category's hand-built part (Maintenance's saved configurations)
      Loader {
        active: root.page !== ""
        visible: active
        Layout.fillWidth: true
        source: active ? Qt.resolvedUrl(root.page + ".qml") : ""
      }
    }
  }
}
