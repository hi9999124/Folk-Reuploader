package config

import (
	"bufio"
	"errors"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/kartFr/Asset-Reuploader/internal/files"
)

var (
	config        = make(map[string]string, 0)
	defaultConfig = map[string]string{
		"port":           "38073",
		"cookie_file":    "cookie.txt",
		"api_key":        "",
		"api_key_file":   "api-key.txt",
		"bind":           "127.0.0.1",
		"auto_studio":    "true",
		"last_place_id":  "",
		"last_creator_id": "",
		"last_is_group":  "false",
		"last_place_name": "",
	}
)

func init() {
	contents, err := files.Read("config.ini")
	if err != nil && !os.IsNotExist(err) {
		log.Printf("failed reading config.ini, using defaults: %v", err)
	}
	if err != nil {
		contents = ""
	}

	scanner := bufio.NewScanner(strings.NewReader(contents))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		split := strings.SplitN(line, "=", 2)
		if len(split) != 2 {
			continue
		}

		key := strings.TrimSpace(split[0])
		if key == "" {
			continue
		}
		config[key] = split[1]
	}

	for i, v := range defaultConfig {
		if _, exists := config[i]; exists {
			continue
		}
		config[i] = v
	}

	keyFile := config["api_key_file"]
	data, err := files.Read(keyFile)
	switch {
	case err == nil && strings.TrimSpace(data) != "":
		config["api_key"] = strings.TrimSpace(data)
	case err != nil && errors.Is(err, os.ErrNotExist):
		if k := strings.TrimSpace(config["api_key"]); k != "" {
			if wErr := files.Write(keyFile, k); wErr != nil {
				log.Printf("could not migrate api key to %s: %v", keyFile, wErr)
			}
		}
	}

}

// PersistAPIKey writes the current api_key to api-key_file (Open Cloud key). Call after Set("api_key", ...).
func PersistAPIKey() error {
	k := strings.TrimSpace(config["api_key"])
	if k == "" {
		return nil
	}
	return files.Write(config["api_key_file"], k)
}

func Get(key string) string {
	return config[key]
}

func Set(key string, value string) {
	config[key] = value
}

func PersistStudio(placeID, creatorID int64, isGroup bool, placeName string) {
	Set("last_place_id", strconv.FormatInt(placeID, 10))
	Set("last_creator_id", strconv.FormatInt(creatorID, 10))
	if isGroup {
		Set("last_is_group", "true")
	} else {
		Set("last_is_group", "false")
	}
	Set("last_place_name", placeName)
	_ = Save()
}

func Save() error {
	var out strings.Builder
	keys := make([]string, 0, len(config))
	for key := range config {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	for _, key := range keys {
		if key == "api_key" {
			continue
		}
		out.WriteString(key)
		out.WriteByte('=')
		out.WriteString(config[key])
		out.WriteByte('\n')
	}
	return files.Write("config.ini", out.String())
}
