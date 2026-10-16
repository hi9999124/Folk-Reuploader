package studio

import (
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"
)

type Session struct {
	Connected     bool      `json:"connected"`
	PluginVersion string    `json:"pluginVersion"`
	PlaceID       int64     `json:"placeId"`
	PlaceName     string    `json:"placeName"`
	CreatorID     int64     `json:"creatorId"`
	IsGroup       bool      `json:"isGroup"`
	LastHello     time.Time `json:"lastHello"`
}

type Hub struct {
	mu      sync.RWMutex
	session Session
	running bool
	checked time.Time
}

func NewHub() *Hub {
	h := &Hub{}
	go h.watchProcess()
	return h
}

func (h *Hub) Hello(pluginVersion, placeName string, placeID, creatorID int64, isGroup bool) Session {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.session = Session{
		Connected:     true,
		PluginVersion: pluginVersion,
		PlaceID:       placeID,
		PlaceName:     placeName,
		CreatorID:     creatorID,
		IsGroup:       isGroup,
		LastHello:     time.Now(),
	}
	return h.session
}

func (h *Hub) Snapshot() Session {
	h.mu.RLock()
	defer h.mu.RUnlock()
	s := h.session
	if s.Connected && time.Since(s.LastHello) > 8*time.Second {
		s.Connected = false
	}
	s.Connected = s.Connected || h.running
	return s
}

func (h *Hub) ProcessRunning() bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.running
}

func (h *Hub) watchProcess() {
	for {
		running := detectStudio()
		h.mu.Lock()
		h.running = running
		h.checked = time.Now()
		if !running && time.Since(h.session.LastHello) > 8*time.Second {
			h.session.Connected = false
		}
		h.mu.Unlock()
		time.Sleep(2 * time.Second)
	}
}

func detectStudio() bool {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("tasklist", "/FI", "IMAGENAME eq RobloxStudioBeta.exe")
	case "darwin":
		cmd = exec.Command("pgrep", "-f", "RobloxStudio")
	default:
		cmd = exec.Command("pgrep", "-f", "RobloxStudio")
	}
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	s := string(out)
	if runtime.GOOS == "windows" {
		return strings.Contains(s, "RobloxStudioBeta.exe")
	}
	return strings.TrimSpace(s) != ""
}
