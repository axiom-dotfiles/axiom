package yamlsrc

import (
	"bytes"
	"fmt"
	"path"
	"strings"

	"go.yaml.in/yaml/v3"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

// Inline is the root properties that stay in index.yaml instead of a
// section file of their own.
var Inline = map[string]bool{"$schema": true, "version": true}

// DefinitionGroup is the folder under definitions/ a definition's file
// goes in, by its name.
func DefinitionGroup(name string) string {
	switch {
	case strings.HasSuffix(name, "Widget") || name == "WidgetLayout":
		return "widgets"
	case strings.HasSuffix(name, "OverlayModule"):
		return "modules"
	case strings.HasSuffix(name, "OverlayView"):
		return "views"
	}
	return "common"
}

// Split writes a root schema as the source files (path → content):
// index.yaml, a section file per root property (but Inline's), a
// definition file per definition, and annotations.yaml registering every
// x-* key used, each with summaries[name] (may be empty).
func Split(root *jsonx.Object, summaries map[string]string) (map[string][]byte, error) {
	files := map[string][]byte{}
	index := jsonx.NewObject()
	var sections, definitions []any
	for _, key := range root.Keys() {
		switch key {
		case "properties":
			props, _ := root.Value(key).(*jsonx.Object)
			inline := jsonx.NewObject()
			for _, name := range props.Keys() {
				if Inline[name] {
					inline.Set(name, props.Value(name))
					continue
				}
				sections = append(sections, name)
				data, err := encode(props.Value(name), schemaNode, fmt.Sprintf("The %s section of the config (config.json's %q).", name, name))
				if err != nil {
					return nil, err
				}
				files[path.Join(SectionsDir, name+".yaml")] = data
			}
			index.Set("properties", inline)
			index.Set("sections", jsonx.Arr(sections...))
		case "definitions":
			defs, _ := root.Value(key).(*jsonx.Object)
			for _, name := range defs.Keys() {
				definitions = append(definitions, name)
				data, err := encode(defs.Value(name), schemaNode, fmt.Sprintf("The %s definition (#/definitions/%s).", name, name))
				if err != nil {
					return nil, err
				}
				files[path.Join(DefinitionsDir, DefinitionGroup(name), name+".yaml")] = data
			}
			index.Set("definitions", jsonx.Arr(definitions...))
		default:
			index.Set(key, root.Value(key))
		}
	}
	data, err := encode(index, indexNode, "The root of the config schema. `axiom schema build` joins it, the sections\n"+
		"(sections/<Name>.yaml, in the order `sections` lists them, after `properties`)\n"+
		"and the definitions (definitions/**/<Name>.yaml) into config/json/config.schema.json.")
	if err != nil {
		return nil, err
	}
	files[IndexFile] = data

	used := map[string]bool{}
	collectAnnotations(root, used)
	reg := jsonx.NewObject()
	for _, name := range sortedKeys(used) {
		reg.Set(name, summaries[name])
	}
	data, err = encode(reg, dataNode, "Every x-* annotation the schema may use, with what it means in one line (the\n"+
		"whole story: docs/dev/core/schema-annotations.md). A key not listed here is\n"+
		"refused, so a typo can't pass as an annotation.")
	if err != nil {
		return nil, err
	}
	files[AnnotationsFile] = data
	return files, nil
}

func collectAnnotations(v any, used map[string]bool) {
	switch t := v.(type) {
	case *jsonx.Object:
		for _, k := range t.Keys() {
			if strings.HasPrefix(k, "x-") {
				used[k] = true
			}
			collectAnnotations(t.Value(k), used)
		}
	case *jsonx.Array:
		for _, x := range t.Items {
			collectAnnotations(x, used)
		}
	}
}

// What a value is to the writer: a schema node (keys are keywords), the
// index, or data (a default, enum, annotation value)
type role int

const (
	schemaNode role = iota
	indexNode
	dataNode
	schemaMap // properties / definitions: names → schema nodes
	schemaList
)

func encode(v any, r role, comment string) ([]byte, error) {
	n := toNode(v, r)
	doc := &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{n}}
	if comment != "" {
		doc.HeadComment = comment
	}
	var b bytes.Buffer
	enc := yaml.NewEncoder(&b)
	enc.SetIndent(2)
	if err := enc.Encode(doc); err != nil {
		return nil, err
	}
	if err := enc.Close(); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}

func childRole(parent role, key string) role {
	switch parent {
	case schemaNode, indexNode:
		switch key {
		case "properties", "definitions", "patternProperties":
			return schemaMap
		case "items", "additionalProperties":
			return schemaNode
		case "oneOf":
			return schemaList
		}
		return dataNode
	case schemaMap:
		return schemaNode
	case schemaList:
		return schemaNode
	}
	return dataNode
}

func toNode(v any, r role) *yaml.Node {
	switch t := v.(type) {
	case *jsonx.Object:
		n := &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map"}
		for _, k := range t.Keys() {
			n.Content = append(n.Content, keyNode(k), toNode(t.Value(k), childRole(r, k)))
		}
		if r == dataNode && flowable(v) {
			n.Style = yaml.FlowStyle
		}
		return n
	case *jsonx.Array:
		n := &yaml.Node{Kind: yaml.SequenceNode, Tag: "!!seq"}
		itemRole := dataNode
		if r == schemaList {
			itemRole = schemaNode
		}
		for _, x := range t.Items {
			n.Content = append(n.Content, toNode(x, itemRole))
		}
		if r != schemaList && flowable(v) {
			n.Style = yaml.FlowStyle
		}
		return n
	}
	return scalarNode(v)
}

func keyNode(k string) *yaml.Node {
	n := scalarNode(k)
	return n
}

func scalarNode(v any) *yaml.Node {
	switch t := v.(type) {
	case nil:
		return &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!null", Value: "null"}
	case bool:
		return &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!bool", Value: fmt.Sprint(t)}
	case float64:
		text := jsonx.FormatNumber(t)
		tag := "!!float"
		if decimalInt.MatchString(text) {
			tag = "!!int"
		}
		return &yaml.Node{Kind: yaml.ScalarNode, Tag: tag, Value: text}
	case string:
		n := &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: t}
		if needsQuotes(t) {
			n.Style = yaml.DoubleQuotedStyle
		}
		return n
	}
	panic("yamlsrc: not a JSON value")
}

// needsQuotes: a string that, written plain, would read back as something
// else (or that this reader refuses plain).
func needsQuotes(s string) bool {
	if s == "" || yaml11Bools[strings.ToLower(s)] {
		return true
	}
	switch strings.ToLower(s) {
	case "true", "false", "null", "~", ".inf", "-.inf", ".nan":
		return true
	}
	return decimalFloat.MatchString(s) || decimalInt.MatchString(s) || strings.ContainsAny(s[:1], "0123456789+-.")
}

// flowable: a short list or mapping of scalars, written on one line
func flowable(v any) bool {
	width := 0
	switch t := v.(type) {
	case *jsonx.Array:
		if len(t.Items) == 0 {
			return true
		}
		for _, x := range t.Items {
			if !isScalar(x) {
				return false
			}
			width += len(jsonx.ToString(x)) + 4
		}
	case *jsonx.Object:
		if t.Len() == 0 {
			return true
		}
		for _, k := range t.Keys() {
			x := t.Value(k)
			if !isScalar(x) {
				return false
			}
			width += len(k) + len(jsonx.ToString(x)) + 6
		}
	}
	return width <= 72
}

func isScalar(v any) bool {
	switch v.(type) {
	case *jsonx.Object, *jsonx.Array:
		return false
	}
	return true
}

func sortedKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	for i := 1; i < len(keys); i++ {
		for j := i; j > 0 && keys[j] < keys[j-1]; j-- {
			keys[j], keys[j-1] = keys[j-1], keys[j]
		}
	}
	return keys
}
