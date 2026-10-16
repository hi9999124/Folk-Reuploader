package main

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/kartFr/Asset-Reuploader/internal/app/assets"
	"github.com/kartFr/Asset-Reuploader/internal/app/config"
	"github.com/kartFr/Asset-Reuploader/internal/app/request"
	"github.com/kartFr/Asset-Reuploader/internal/app/response"
	"github.com/kartFr/Asset-Reuploader/internal/app/studio"
	"github.com/kartFr/Asset-Reuploader/internal/console"
	"github.com/kartFr/Asset-Reuploader/internal/files"
	"github.com/kartFr/Asset-Reuploader/internal/roblox"
)

type cliOptions struct {
	AssetType string
	IDs       string
	PlaceID   int64
	CreatorID int64
	IsGroup   bool
	Export    bool
}

func runCLI(c *roblox.Client, hub *studio.Hub, opt cliOptions) error {
	fmt.Println(console.Cream("  terminal-only mode — no plugin required"))
	fmt.Println()

	opt.AssetType = strings.TrimSpace(opt.AssetType)
	if opt.AssetType == "" {
		fmt.Println(console.Dim("  1) Animation   2) Mesh   3) Sound"))
		choice, err := console.Input("  type: ")
		if err != nil {
			return err
		}
		switch strings.TrimSpace(choice) {
		case "1", "animation", "Animation":
			opt.AssetType = "Animation"
		case "2", "mesh", "Mesh":
			opt.AssetType = "Mesh"
		case "3", "sound", "Sound", "audio", "Audio":
			opt.AssetType = "Sound"
		default:
			opt.AssetType = "Animation"
		}
	}
	if opt.AssetType == "audio" || opt.AssetType == "Audio" {
		opt.AssetType = "Sound"
	}
	if !assets.DoesModuleExist(opt.AssetType) {
		return fmt.Errorf("unknown asset type %q (Animation, Mesh, Sound)", opt.AssetType)
	}

	ids := parseIDs(opt.IDs)
	if len(ids) == 0 {
		raw, err := console.Input("  asset ids (comma or space): ")
		if err != nil {
			return err
		}
		ids = parseIDs(raw)
	}
	if len(ids) == 0 {
		return fmt.Errorf("no asset ids")
	}

	sess := hub.Snapshot()
	if opt.PlaceID == 0 {
		opt.PlaceID = sess.PlaceID
		if opt.PlaceID == 0 {
			opt.PlaceID = atoi64(config.Get("last_place_id"))
		}
	}
	if opt.CreatorID == 0 {
		opt.CreatorID = sess.CreatorID
		if opt.CreatorID == 0 {
			opt.CreatorID = atoi64(config.Get("last_creator_id"))
		}
	}
	if !opt.IsGroup && config.Get("last_is_group") == "true" {
		opt.IsGroup = true
	}

	if opt.PlaceID == 0 {
		raw, err := console.Input("  place id: ")
		if err != nil {
			return err
		}
		opt.PlaceID = atoi64(raw)
	} else {
		fmt.Println(console.Green("  ✔") + console.Cream(fmt.Sprintf(" auto-filled place %d", opt.PlaceID)))
	}
	if opt.CreatorID == 0 {
		raw, err := console.Input("  creator id: ")
		if err != nil {
			return err
		}
		opt.CreatorID = atoi64(raw)
	} else {
		fmt.Println(console.Green("  ✔") + console.Cream(fmt.Sprintf(" auto-filled creator %d", opt.CreatorID)))
	}

	if opt.PlaceID == 0 || opt.CreatorID == 0 {
		return fmt.Errorf("place id and creator id are required (publish in Studio once to auto-fill next time)")
	}

	fmt.Println()
	fmt.Println(console.Box("CLI JOB", []string{
		"type      " + opt.AssetType,
		fmt.Sprintf("ids       %d assets", len(ids)),
		fmt.Sprintf("place     %d", opt.PlaceID),
		fmt.Sprintf("creator   %d", opt.CreatorID),
	}, 56))
	fmt.Println()
	console.Spin("starting reupload", 500*time.Millisecond)

	var exported []response.ResponseItem
	resp := response.New(func(i response.ResponseItem) {
		if opt.Export {
			exported = append(exported, i)
		}
	})

	req := &request.RawRequest{
		PlaceID:       opt.PlaceID,
		CreatorID:     opt.CreatorID,
		IDs:           ids,
		PluginVersion: CompatiblePluginVersion,
		AssetType:     opt.AssetType,
		ExportJSON:    opt.Export,
		IsGroup:       opt.IsGroup,
	}

	start, err := assets.NewReuploadHandlerWithType(opt.AssetType, c, req, resp)
	if err != nil {
		return err
	}
	if err := start(); err != nil {
		return err
	}

	if opt.Export {
		name := getOutputFileName(opt.AssetType)
		j, err := json.MarshalIndent(exported, "", "  ")
		if err != nil {
			return err
		}
		if err := files.Write(name, string(j)); err != nil {
			return err
		}
		fmt.Println(console.Green("  ✔") + console.Cream(" wrote "+name))
	}

	fmt.Println(console.Green("  ✔") + console.Cream(" Folk CLI finished"))
	return nil
}

func parseIDs(raw string) []int64 {
	raw = strings.ReplaceAll(raw, " ", ",")
	parts := strings.Split(raw, ",")
	out := make([]int64, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		n, err := strconv.ParseInt(p, 10, 64)
		if err != nil {
			continue
		}
		out = append(out, n)
	}
	return out
}
