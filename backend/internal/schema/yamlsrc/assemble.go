package yamlsrc

import (
	"fmt"
	"io/fs"
	"path"
	"sort"
	"strings"

	"github.com/axiom-shell/axiom/backend/internal/jsonx"
)

// The source layout, relative to config/schema/
const (
	IndexFile       = "index.yaml"
	AnnotationsFile = "annotations.yaml"
	SectionsDir     = "sections"
	DefinitionsDir  = "definitions"
)

// Assemble reads the schema source in fsys (config/schema/) and joins it
// into the root schema: index.yaml as the root, its `properties` followed
// by sections/<Name>.yaml for each name `sections` lists, and
// definitions/**/<Name>.yaml for each name `definitions` lists, in those
// orders. Every file must be listed, every listed name must have a file,
// and the result must pass Check.
func Assemble(fsys fs.FS) (*jsonx.Object, error) {
	a := &assembler{fsys: fsys, pos: Positions{}}
	root := a.assemble()
	registry := a.annotations()
	// Report everything at once: the listing problems and what the files
	// that did read hold
	if root != nil && registry != nil {
		a.errs = append(a.errs, Check(root, registry, a.pos)...)
	}
	if len(a.errs) > 0 {
		return nil, a.errs
	}
	return root, nil
}

type assembler struct {
	fsys fs.FS
	pos  Positions
	errs Errors
}

func (a *assembler) read(name string) any {
	data, err := fs.ReadFile(a.fsys, name)
	if err != nil {
		a.errs = append(a.errs, &Error{File: name, Msg: err.Error()})
		return nil
	}
	v, _, err := ParsePositions(name, data, a.pos)
	if err != nil {
		if es, ok := err.(Errors); ok {
			a.errs = append(a.errs, es...)
		} else {
			a.errs = append(a.errs, err.(*Error))
		}
		return nil
	}
	return v
}

func (a *assembler) names(index *jsonx.Object, key string) []string {
	list, ok := index.Value(key).(*jsonx.Array)
	if !ok {
		a.errs = append(a.errs, a.pos.At(index, key, IndexFile, key+" must be a list of names"))
		return nil
	}
	var names []string
	seen := map[string]bool{}
	for _, v := range list.Items {
		name, ok := v.(string)
		if !ok || name == "" || strings.ContainsAny(name, "/\\") {
			a.errs = append(a.errs, a.pos.At(index, key, IndexFile, fmt.Sprintf("%s: %v isn't a name", key, v)))
			continue
		}
		if seen[name] {
			a.errs = append(a.errs, a.pos.At(index, key, IndexFile, fmt.Sprintf("%s lists %s twice", key, name)))
			continue
		}
		seen[name] = true
		names = append(names, name)
	}
	return names
}

func (a *assembler) assemble() *jsonx.Object {
	index, ok := a.read(IndexFile).(*jsonx.Object)
	if !ok {
		if len(a.errs) == 0 {
			a.errs = append(a.errs, &Error{File: IndexFile, Msg: "must be a mapping"})
		}
		return nil
	}
	sections := a.names(index, "sections")
	definitions := a.names(index, "definitions")
	sectionFiles := a.files(SectionsDir, false)
	definitionFiles := a.files(DefinitionsDir, true)
	a.listedExactly(index, "sections", sections, sectionFiles)
	a.listedExactly(index, "definitions", definitions, definitionFiles)
	if !index.Has("properties") {
		a.errs = append(a.errs, &Error{File: IndexFile, Msg: "needs properties (the sections follow them)"})
	}

	root := jsonx.NewObject()
	for _, key := range index.Keys() {
		switch key {
		case "sections":
			continue
		case "properties":
			props, ok := index.Value(key).(*jsonx.Object)
			if !ok {
				a.errs = append(a.errs, a.pos.At(index, key, IndexFile, "properties must be a mapping"))
				continue
			}
			for _, name := range sections {
				if props.Has(name) {
					a.errs = append(a.errs, a.pos.At(props, name, IndexFile, name+" is both in properties and a section file"))
					continue
				}
				if file, ok := sectionFiles[name]; ok {
					props.Set(name, a.read(file))
				}
			}
			root.Set(key, props)
		case "definitions":
			defs := jsonx.NewObject()
			for _, name := range definitions {
				if file, ok := definitionFiles[name]; ok {
					defs.Set(name, a.read(file))
				}
			}
			root.Set(key, defs)
		default:
			root.Set(key, index.Value(key))
		}
	}
	return root
}

// files maps each .yaml file's name (its stem) under dir to its path.
func (a *assembler) files(dir string, nested bool) map[string]string {
	found := map[string]string{}
	err := fs.WalkDir(a.fsys, dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if p != dir && !nested {
				a.errs = append(a.errs, &Error{File: p, Msg: "sections/ holds files only"})
				return fs.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(p, ".yaml") {
			a.errs = append(a.errs, &Error{File: p, Msg: "only .yaml files belong here"})
			return nil
		}
		name := strings.TrimSuffix(path.Base(p), ".yaml")
		if other, dup := found[name]; dup {
			a.errs = append(a.errs, &Error{File: p, Msg: "the name " + name + " is also " + other})
			return nil
		}
		found[name] = p
		return nil
	})
	if err != nil {
		a.errs = append(a.errs, &Error{File: dir, Msg: err.Error()})
	}
	return found
}

func (a *assembler) listedExactly(index *jsonx.Object, key string, listed []string, files map[string]string) {
	isListed := map[string]bool{}
	for _, name := range listed {
		isListed[name] = true
		if _, ok := files[name]; !ok {
			a.errs = append(a.errs, a.pos.At(index, key, IndexFile, fmt.Sprintf("%s lists %s, which has no file", key, name)))
		}
	}
	var unlisted []string
	for name, file := range files {
		if !isListed[name] {
			unlisted = append(unlisted, file)
		}
	}
	sort.Strings(unlisted)
	for _, file := range unlisted {
		a.errs = append(a.errs, &Error{File: file, Msg: fmt.Sprintf("not listed in %s's %s", IndexFile, key)})
	}
}

// annotations reads the registry: every x-* key the schema may use (nil
// when it can't be read).
func (a *assembler) annotations() map[string]bool {
	before := len(a.errs)
	reg, ok := a.read(AnnotationsFile).(*jsonx.Object)
	if len(a.errs) > before {
		return nil
	}
	if !ok {
		a.errs = append(a.errs, &Error{File: AnnotationsFile, Msg: "must be a mapping of annotation names"})
		return nil
	}
	names := map[string]bool{}
	for _, k := range reg.Keys() {
		if !strings.HasPrefix(k, "x-") {
			a.errs = append(a.errs, a.pos.At(reg, k, AnnotationsFile, k+" isn't an x-* name"))
			continue
		}
		names[k] = true
	}
	return names
}
