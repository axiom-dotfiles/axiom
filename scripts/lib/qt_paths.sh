# shellcheck shell=bash
# Where Qt 6's tools are, for the dev checks (sourced, not run): sets
# qt_bin. $QT_BIN wins, else qmake6 says (Fedora keeps them in
# /usr/lib64/qt6/bin), else Arch's /usr/lib/qt6/bin. Not PATH: the
# qmlformat there may be Qt 5's, which fails silently on
# `pragma ComponentBehavior`.
#
#   source "$root/scripts/lib/qt_paths.sh"
#   "$qt_bin/qmlformat" …

qt_bin="${QT_BIN:-}"
if [ -z "$qt_bin" ] && command -v qmake6 >/dev/null 2>&1; then
  qt_bin="$(qmake6 -query QT_INSTALL_BINS 2>/dev/null)"
fi
qt_bin="${qt_bin:-/usr/lib/qt6/bin}"
