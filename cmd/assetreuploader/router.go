package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/kartFr/Asset-Reuploader/internal/app/assets"
	"github.com/kartFr/Asset-Reuploader/internal/app/config"
	"github.com/kartFr/Asset-Reuploader/internal/app/request"
	"github.com/kartFr/Asset-Reuploader/internal/app/response"
	"github.com/kartFr/Asset-Reuploader/internal/app/studio"
	"github.com/kartFr/Asset-Reuploader/internal/color"
	"github.com/kartFr/Asset-Reuploader/internal/console"
	"github.com/kartFr/Asset-Reuploader/internal/files"
	"github.com/kartFr/Asset-Reuploader/internal/roblox"
)

type hostState struct {
	mu        sync.Mutex
	busy      bool
	finished  bool
	exporting bool
	outFile   string
	status    string
	lastErr   string
	started   time.Time
}

func serve(c *roblox.Client, hub *studio.Hub, tui bool) error {
	port := config.Get("port")
	bind := config.Get("bind")
	if bind == "" {
		bind = "127.0.0.1"
	}

	state := &hostState{finished: true, status: "waiting for Studio"}
	respHistory := make([]response.ResponseItem, 0)
	resp := response.New(func(i response.ResponseItem) {
		if state.exporting {
			respHistory = append(respHistory, i)
			j, err := json.Marshal(respHistory)
			if err != nil {
				log.Fatal(err)
			}
			if err := files.Write(state.outFile, string(j)); err != nil {
				log.Fatal(err)
			}
		}
	})

	mux := http.NewServeMux()
	withJSON := func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Folk-Client")
			w.Header().Set("Cache-Control", "no-store")
			next(w, r)
		}
	}

	writeEvents := func(w http.ResponseWriter) {
		state.mu.Lock()
		busy := state.busy
		finished := state.finished
		state.mu.Unlock()

		if resp.Len() == 0 && !busy {
			if !finished {
				state.mu.Lock()
				state.finished = true
				state.busy = false
				state.exporting = false
				state.status = "idle — rerun from Studio anytime"
				state.mu.Unlock()
				resp.Clear()
				respHistory = make([]response.ResponseItem, 0)
				fmt.Fprint(w, "done")
				fmt.Println(console.Green("  ✔") + console.Cream(" finished reuploading (host stays up)"))
			}
			return
		}
		w.Header().Set("Content-Type", "application/json")
		if err := resp.EncodeJSON(json.NewEncoder(w)); err != nil {
			log.Fatal(err)
		} else {
			resp.Clear()
		}
	}

	health := func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		sess := hub.Snapshot()
		state.mu.Lock()
		status := state.status
		busy := state.busy
		state.mu.Unlock()
		json.NewEncoder(w).Encode(map[string]any{
			"ok":      true,
			"name":    "Folk Reuploader",
			"version": "2.0.0",
			"plugin":  CompatiblePluginVersion,
			"user":    c.UserInfo.Username,
			"userId":  c.UserInfo.ID,
			"port":    port,
			"bind":    bind,
			"busy":    busy,
			"status":  status,
			"studio":  sess,
		})
	}

	hello := func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			PluginVersion string `json:"pluginVersion"`
			PlaceID       int64  `json:"placeId"`
			CreatorID     int64  `json:"creatorId"`
			IsGroup       bool   `json:"isGroup"`
			PlaceName     string `json:"placeName"`
			Port          int    `json:"port"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		sess := hub.Hello(body.PluginVersion, body.PlaceName, body.PlaceID, body.CreatorID, body.IsGroup)
		if body.PlaceID != 0 {
			config.PersistStudio(body.PlaceID, body.CreatorID, body.IsGroup, body.PlaceName)
		}
		state.mu.Lock()
		if !state.busy {
			state.status = "Studio linked"
			if body.PlaceName != "" {
				state.status = "Studio · " + body.PlaceName
			}
		}
		state.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"ok":      true,
			"user":    c.UserInfo.Username,
			"session": sess,
			"filled": map[string]any{
				"placeId":   body.PlaceID,
				"creatorId": body.CreatorID,
				"isGroup":   body.IsGroup,
			},
		})
	}

	startJob := func(w http.ResponseWriter, r *http.Request) {
		state.mu.Lock()
		if state.busy || !state.finished {
			state.mu.Unlock()
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		state.mu.Unlock()

		var req request.RawRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			color.Error.Println(err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		if CompatiblePluginVersion != "" && req.PluginVersion != CompatiblePluginVersion {
			w.WriteHeader(http.StatusConflict)
			return
		}
		if exists := assets.DoesModuleExist(req.AssetType); !exists {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		startReupload, err := assets.NewReuploadHandlerWithType(req.AssetType, c, &req, resp)
		if err != nil {
			color.Error.Println(err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		state.mu.Lock()
		state.exporting = req.ExportJSON
		if req.ExportJSON {
			state.outFile = getOutputFileName(req.AssetType)
		}
		state.busy = true
		state.finished = false
		state.started = time.Now()
		state.status = "reuploading " + req.AssetType
		state.lastErr = ""
		state.mu.Unlock()

		go func() {
			err := startReupload()
			state.mu.Lock()
			state.busy = false
			if err != nil {
				state.finished = true
				state.lastErr = err.Error()
				state.status = "failed"
				state.mu.Unlock()
				color.Error.Println("Failed to start reuploading: ", err)
				return
			}
			duration := time.Since(state.started)
			state.status = "waiting for Studio to remap ids"
			state.mu.Unlock()
			fmt.Printf("  reupload took %d hours, %d minutes, %d seconds\n", int(duration.Hours()), int(duration.Minutes())%60, int(duration.Seconds())%60)
			fmt.Println(console.Dim("  waiting for plugin to finish changing ids…"))
		}()

		w.WriteHeader(http.StatusOK)
	}

	mux.HandleFunc("GET /", withJSON(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		writeEvents(w)
	}))
	mux.HandleFunc("GET /v1/health", withJSON(health))
	mux.HandleFunc("GET /v1/events", withJSON(func(w http.ResponseWriter, r *http.Request) {
		writeEvents(w)
	}))
	mux.HandleFunc("POST /v1/studio/hello", withJSON(hello))
	mux.HandleFunc("POST /reupload", withJSON(startJob))
	mux.HandleFunc("POST /v1/reupload", withJSON(startJob))

	addr := bind + ":" + port
	server := &http.Server{Addr: addr, Handler: mux}

	errCh := make(chan error, 1)
	go func() {
		errCh <- server.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		return err
	case <-time.After(80 * time.Millisecond):
	}

	if tui {
		runDashboard(c, hub, state, addr)
		return server.Close()
	}

	fmt.Println(console.Green("  ✔") + console.Cream(" Folk host ") + console.Amber(addr))
	fmt.Println(console.Dim("  open Roblox Studio — the Folk plugin auto-connects"))
	waitForInterrupt()
	return server.Close()
}

func getOutputFileName(reuploadType string) string {
	t := time.Now()
	return fmt.Sprintf("Output_%s_%s.json", reuploadType, t.Format("2006-01-02_15-04-05"))
}

func runDashboard(c *roblox.Client, hub *studio.Hub, state *hostState, addr string) {
	console.SetLiveUI(true)
	console.HideCursor()
	defer func() {
		console.ShowCursor()
		console.SetLiveUI(false)
	}()

	ticker := time.NewTicker(120 * time.Millisecond)
	defer ticker.Stop()
	pulse := 0
	frames := []string{"░", "▒", "▓", "█", "▓", "▒"}

	stop := make(chan osSignal, 1)
	go func() {
		waitForInterrupt()
		stop <- osSignal{}
	}()

	for {
		select {
		case <-stop:
			return
		case <-ticker.C:
			sess := hub.Snapshot()
			state.mu.Lock()
			status := state.status
			busy := state.busy
			lastErr := state.lastErr
			state.mu.Unlock()

			studioLine := "searching for Roblox Studio"
			if hub.ProcessRunning() && !sess.Connected {
				studioLine = "Studio is open — install/open the Folk plugin"
			}
			if sess.Connected && sess.PlaceID != 0 {
				name := sess.PlaceName
				if name == "" {
					name = "place"
				}
				kind := "User"
				if sess.IsGroup {
					kind = "Group"
				}
				studioLine = fmt.Sprintf("%s  ·  %s %d  ·  place %d", name, kind, sess.CreatorID, sess.PlaceID)
			} else if sess.Connected {
				studioLine = "plugin linked — publish the place to auto-fill ids"
			}

			link := console.StatusDot(sess.Connected)
			bar := strings.Repeat(frames[pulse%len(frames)], 3)
			pulse++

			rows := []string{
				fmt.Sprintf("account   %s (%d)", c.UserInfo.Username, c.UserInfo.ID),
				fmt.Sprintf("host      http://%s", addr),
				fmt.Sprintf("studio    %s  %s", link, studioLine),
				fmt.Sprintf("queue     %s", status),
			}
			if busy {
				if console.LiveUI() {
					console.SetLiveUI(false)
					console.ShowCursor()
					fmt.Println()
					fmt.Println(console.Amber("  ▸ reupload in progress — logs below"))
				}
				continue
			}
			if !console.LiveUI() {
				console.SetLiveUI(true)
				console.HideCursor()
			}
			if lastErr != "" {
				rows = append(rows, "error     "+lastErr)
			}
			rows = append(rows, "hint      keep this window open · plugin reconnects by itself")

			console.HomeCursor()
			fmt.Print("\x1b[0J")
			fmt.Print(console.Banner())
			fmt.Println()
			fmt.Println(console.Box("FOLK LINK", rows, 72))
			fmt.Println()
			fmt.Println(console.Dim("  ctrl+c to stop") + "   " + console.Amber(bar+" folk"))
		}
	}
}

type osSignal struct{}
