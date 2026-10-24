// Package actions is what every compositor's bind merge shares: axiom's
// bind actions as components/methods/BindActions.qml has them, and the
// commands that are one of them (axiom's own IPC calls; volume, brightness
// and media commands). Pure: the caller reads BindActions.qml.
package actions

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

// Table is BindActions' tables the merge needs.
type Table struct {
	ipc []ipcPattern
	// Repeating: the actions axiom repeats while held by default
	// (BindActions.actionFlags)
	Repeating map[string]bool
}

type ipcPattern struct {
	action string
	re     *regexp.Regexp
}

// The file whose tables Parse reads, from the tree
const File = "components/methods/BindActions.qml"

var (
	ipcEntry  = regexp.MustCompile(`"(\w+)": \["([^"]+)"`)
	flagEntry = regexp.MustCompile(`"(\w+)": \[([^\]]*)\]`)
)

// Parse reads BindActions.qml's text: each IPC call of ipcActions (its
// {call} and {0} as what they match), and actionFlags' repeating actions.
func Parse(qml string) (*Table, error) {
	ipcTable, err := between(qml, "ipcActions:", "compositorActions:")
	if err != nil {
		return nil, err
	}
	flagTable, err := between(qml, "actionFlags:", "flagNames:")
	if err != nil {
		return nil, err
	}
	t := &Table{Repeating: map[string]bool{}}
	for _, m := range ipcEntry.FindAllStringSubmatch(ipcTable, -1) {
		pattern := regexp.QuoteMeta(m[2])
		pattern = strings.ReplaceAll(pattern, regexp.QuoteMeta("{call}"), `(?P<call>\w+)`)
		pattern = strings.ReplaceAll(pattern, regexp.QuoteMeta("{0}"), `(?P<arg>\S+)`)
		re, err := regexp.Compile("^" + pattern + "$")
		if err != nil {
			return nil, fmt.Errorf("%s: %s: %w", File, m[1], err)
		}
		t.ipc = append(t.ipc, ipcPattern{m[1], re})
	}
	for _, m := range flagEntry.FindAllStringSubmatch(flagTable, -1) {
		if strings.Contains(m[2], `"repeating"`) {
			t.Repeating[m[1]] = true
		}
	}
	return t, nil
}

func between(text, from, to string) (string, error) {
	i := strings.Index(text, from)
	j := strings.Index(text, to)
	if i < 0 || j < i {
		return "", fmt.Errorf("%s has no %s table", File, strings.TrimSuffix(from, ":"))
	}
	return text[i:j], nil
}

// What a call names, for actions that open and close (BindActions.calls)
var calls = map[string]string{"toggle": "toggle", "open": "open", "show": "open", "enable": "open",
	"close": "close", "hide": "close", "disable": "close"}

// The axiom binary, by name or path, maybe quoted (Paths.shellCommand)
const axiom = `['"]?(?:\S*/)?axiom['"]?`

var (
	axiomRestart = regexp.MustCompile(`^` + axiom + ` +restart$`)
	axiomLock    = regexp.MustCompile(`^` + axiom + ` +lock$`)
	axiomIPC     = regexp.MustCompile(`^` + axiom + ` +ipc +(.+)$`)
)

// IPCAction is the axiom bind a command calling axiom's IPC is ({ action,
// call, argument }, the last two when its call has them), or nil.
func (t *Table) IPCAction(command string) *jsonx.Object {
	if axiomRestart.MatchString(command) {
		return jsonx.Obj("action", "restartShell")
	}
	var call string
	if axiomLock.MatchString(command) {
		call = "lockscreen lock"
	} else if m := axiomIPC.FindStringSubmatch(command); m != nil {
		call = strings.TrimSpace(m[1])
	} else {
		return nil
	}
	for _, p := range t.ipc {
		m := p.re.FindStringSubmatch(call)
		if m == nil {
			continue
		}
		entry := jsonx.Obj("action", p.action)
		if i := p.re.SubexpIndex("call"); i > 0 && m[i] != "" {
			name, ok := calls[m[i]]
			if !ok {
				name = "toggle"
			}
			entry.Set("call", name)
		}
		if i := p.re.SubexpIndex("arg"); i > 0 && m[i] != "" {
			entry.Set("argument", unquote(m[i]))
		}
		return entry
	}
	return nil
}

func unquote(text string) string {
	text = strings.TrimSpace(text)
	if len(text) >= 2 && text[0] == text[len(text)-1] && (text[0] == '"' || text[0] == '\'') {
		return text[1 : len(text)-1]
	}
	return text
}

const limit = `( -l [0-9.]+)?`

var (
	wpctlUp     = regexp.MustCompile(`^set-volume` + limit + ` @DEFAULT_AUDIO_SINK@ [0-9.]+%?\+` + limit + `$`)
	wpctlDown   = regexp.MustCompile(`^set-volume` + limit + ` @DEFAULT_AUDIO_SINK@ [0-9.]+%?-` + limit + `$`)
	pactlUp     = regexp.MustCompile(`^set-sink-volume @DEFAULT_SINK@ \+[0-9]+%$`)
	pactlDown   = regexp.MustCompile(`^set-sink-volume @DEFAULT_SINK@ -[0-9]+%$`)
	brightUp    = regexp.MustCompile(`^(-\S+ )*set (\+[0-9]+%|[0-9]+%\+)$`)
	brightDown  = regexp.MustCompile(`^(-\S+ )*set [0-9]+%-$`)
	playerctlTo = map[string]string{"play-pause": "mediaPlayPause", "next": "mediaNext", "previous": "mediaPrevious", "stop": "mediaStop"}
)

// MediaAction is the axiom action a volume, brightness or media command is
// (the commands the compositors' example configs bind media keys to), or
// "".
func MediaAction(command string) string {
	words := strings.Fields(command)
	if len(words) == 0 {
		return ""
	}
	tool, rest := words[0], strings.Join(words[1:], " ")
	switch tool {
	case "wpctl":
		switch {
		case wpctlUp.MatchString(rest):
			return "volumeUp"
		case wpctlDown.MatchString(rest):
			return "volumeDown"
		case rest == "set-mute @DEFAULT_AUDIO_SINK@ toggle":
			return "toggleMute"
		case rest == "set-mute @DEFAULT_AUDIO_SOURCE@ toggle":
			return "toggleMicMute"
		}
	case "pactl":
		switch {
		case pactlUp.MatchString(rest):
			return "volumeUp"
		case pactlDown.MatchString(rest):
			return "volumeDown"
		case rest == "set-sink-mute @DEFAULT_SINK@ toggle":
			return "toggleMute"
		case rest == "set-source-mute @DEFAULT_SOURCE@ toggle":
			return "toggleMicMute"
		}
	case "brightnessctl":
		switch {
		case brightUp.MatchString(rest):
			return "brightnessUp"
		case brightDown.MatchString(rest):
			return "brightnessDown"
		}
	case "playerctl":
		return playerctlTo[rest]
	}
	return ""
}
