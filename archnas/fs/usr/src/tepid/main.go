package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

var credentialCache = make(map[string]string)

func usage() error {
	return fmt.Errorf("Usage: %s <template-file>", os.Args[0])
}

func parseKeyValuePairs(input string) (map[string]any, error) {
	result := make(map[string]any)
	fields := strings.FieldsFunc(input, func(r rune) bool { return r == '\n' || r == '\t' })
	for _, field := range fields {
		field = strings.TrimSpace(field)
		if field == "" {
			continue
		}
		kv := strings.SplitN(field, "=", 2)
		if len(kv) != 2 {
			return nil, fmt.Errorf("invalid key=value pair: %q", field)
		}
		result[kv[0]] = kv[1]
	}
	return result, nil
}

func credentialFunc(credName string) (string, error) {
	if v, ok := credentialCache[credName]; ok {
		return v, nil
	}

	var path string
	if filepath.IsAbs(credName) {
		path = credName
	} else {
		dir := os.Getenv("CREDENTIALS_DIRECTORY")
		if dir == "" {
			return "", fmt.Errorf("CREDENTIALS_DIRECTORY is not set and credential path is not absolute")
		}
		path = filepath.Join(dir, credName)
	}

	cmd := exec.Command("systemd-creds", "decrypt", path)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("systemd-creds decrypt failed for %s: %v\n%s", path, err, stderr.String())
	}
	result := strings.TrimSpace(stdout.String())
	credentialCache[credName] = result
	return result, nil
}

func mainE(args []string) error {
	if len(args) != 1 {
		return usage()
	}
	tmplFile := args[0]

	tmplBytes, err := os.ReadFile(tmplFile)
	if err != nil {
		return fmt.Errorf("Error reading template: %w", err)
	}
	tmplText := string(tmplBytes)

	funcs := template.FuncMap{
		"credential": credentialFunc,
	}

	tmpl, err := template.New("tpl").Funcs(funcs).Parse(tmplText)
	if err != nil {
		return fmt.Errorf("Error parsing template: %w", err)
	}

	stdinBytes, err := io.ReadAll(os.Stdin)
	if err != nil {
		return fmt.Errorf("Error reading stdin: %w", err)
	}
	stdinStr := strings.TrimSpace(string(stdinBytes))
	params := map[string]any{}

	if strings.HasPrefix(stdinStr, "{") {
		err = json.Unmarshal(stdinBytes, &params)
		if err != nil {
			return fmt.Errorf("Error parsing JSON: %w", err)
		}
	} else if stdinStr != "" {
		params, err = parseKeyValuePairs(stdinStr)
		if err != nil {
			return fmt.Errorf("Error parsing key=value: %w", err)
		}
	}

	err = tmpl.Execute(os.Stdout, params)
	if err != nil {
		return fmt.Errorf("Error executing template: %w", err)
	}
	return nil
}

func main() {
	if err := mainE(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
