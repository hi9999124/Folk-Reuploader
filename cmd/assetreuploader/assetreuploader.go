package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/kartFr/Asset-Reuploader/internal/app/config"
	"github.com/kartFr/Asset-Reuploader/internal/app/studio"
	"github.com/kartFr/Asset-Reuploader/internal/color"
	"github.com/kartFr/Asset-Reuploader/internal/console"
	"github.com/kartFr/Asset-Reuploader/internal/files"
	"github.com/kartFr/Asset-Reuploader/internal/roblox"
)

var CompatiblePluginVersion = ""

func main() {
	cli := flag.Bool("cli", false, "terminal-only reupload (no plugin wait)")
	noTUI := flag.Bool("no-tui", false, "start the host without the live dashboard")
	portFlag := flag.String("port", "", "override config port")
	assetType := flag.String("type", "", "Animation, Mesh, or Sound (cli mode)")
	idsFlag := flag.String("ids", "", "comma-separated asset ids (cli mode)")
	placeFlag := flag.Int64("place", 0, "place id (cli mode, auto-filled from Studio when possible)")
	creatorFlag := flag.Int64("creator", 0, "creator id (cli mode, auto-filled from Studio when possible)")
	groupFlag := flag.Bool("group", false, "reupload as a group (cli mode)")
	exportFlag := flag.Bool("export", false, "write JSON id map when finished")
	help := flag.Bool("help", false, "show usage")
	flag.Parse()

	if *help {
		printUsage()
		return
	}

	console.EnableVirtualTerminal()
	if *portFlag != "" {
		config.Set("port", *portFlag)
	}

	if !*cli {
		console.PlayIntro()
	} else {
		console.ClearScreen()
		fmt.Print(console.Banner())
		fmt.Println()
	}

	c := authenticate()
	ensureAPIKey()

	hub := studio.NewHub()

	if *cli {
		if err := runCLI(c, hub, cliOptions{
			AssetType: *assetType,
			IDs:       *idsFlag,
			PlaceID:   *placeFlag,
			CreatorID: *creatorFlag,
			IsGroup:   *groupFlag,
			Export:    *exportFlag,
		}); err != nil {
			color.Error.Println(err)
			os.Exit(1)
		}
		return
	}

	if err := serve(c, hub, !*noTUI); err != nil {
		color.Error.Println(err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Print(console.Banner())
	fmt.Println()
	fmt.Println(console.Cream("  Folk Reuploader — plugin host + terminal-only mode"))
	fmt.Println()
	fmt.Println(console.Amber("  folk-reuploader"))
	fmt.Println(console.Dim("      Live dashboard. Roblox Studio auto-connects on the Folk plugin."))
	fmt.Println(console.Amber("  folk-reuploader --cli"))
	fmt.Println(console.Dim("      Interactive terminal reupload. Place/creator auto-fill from last Studio hello."))
	fmt.Println(console.Amber("  folk-reuploader --cli --type Animation --ids 1,2,3 --place 123 --creator 456"))
	fmt.Println(console.Dim("      Fully non-interactive. Add --group and --export as needed."))
	fmt.Println(console.Amber("  folk-reuploader --no-tui --port 38073"))
	fmt.Println(console.Dim("      Headless host for the plugin."))
}

func authenticate() *roblox.Client {
	cookieFile := config.Get("cookie_file")
	fmt.Println(console.Dim("  authenticating…"))

	cookie, readErr := files.Read(cookieFile)
	roblosCookie, legacyAPIKey := parseCookieFile(cookie)
	roblosCookie = firstNonEmpty(roblosCookie, os.Getenv("FOLK_ROBLOSECURITY"), os.Getenv("ROBLOSECURITY"))
	legacyAPIKey = strings.TrimSpace(legacyAPIKey)
	if legacyAPIKey != "" && strings.TrimSpace(config.Get("api_key")) == "" {
		config.Set("api_key", legacyAPIKey)
		if err := config.PersistAPIKey(); err != nil {
			color.Error.Println("Failed to save API key to ", config.Get("api_key_file"), ": ", err)
		}
	}

	c, clientErr := roblox.NewClient(roblosCookie)
	if readErr != nil || clientErr != nil {
		if readErr != nil && !os.IsNotExist(readErr) {
			color.Error.Println(readErr)
		}
		if clientErr != nil && roblosCookie != "" {
			color.Error.Println(clientErr)
		}
		getCookie(c)
	}

	if err := saveCookieFile(c.Cookie); err != nil {
		color.Error.Println("Failed to save cookie: ", err)
	}

	console.Spin("signed in as "+c.UserInfo.Username, 220*time.Millisecond)
	return c
}

func parseCookieFile(content string) (roblosCookie, apiKey string) {
	lines := strings.Split(strings.TrimSpace(content), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "api-key:") {
			apiKey = strings.TrimSpace(strings.TrimPrefix(line, "api-key:"))
		} else if line != "" && !strings.HasPrefix(line, "api-key:") {
			roblosCookie = line
		}
	}
	return roblosCookie, apiKey
}

func saveCookieFile(roblosCookie string) error {
	return files.Write(config.Get("cookie_file"), strings.TrimSpace(roblosCookie)+"\n")
}

func getCookie(c *roblox.Client) {
	fmt.Println(console.Cream("  Paste your .ROBLOSECURITY cookie (kept only in cookie.txt)."))
	for {
		i, err := console.LongInput("  ROBLOSECURITY: ")
		if err != nil {
			color.Error.Println(err)
			continue
		}
		console.Spin("checking cookie", 420*time.Millisecond)
		err = c.SetCookie(i)
		if err != nil {
			color.Error.Println(err)
			continue
		}
		break
	}
}

func ensureAPIKey() {
	currentAPIKey := strings.TrimSpace(config.Get("api_key"))
	if currentAPIKey == "" {
		currentAPIKey = firstNonEmpty(os.Getenv("FOLK_API_KEY"), os.Getenv("ROBLOX_API_KEY"))
		if currentAPIKey != "" {
			config.Set("api_key", currentAPIKey)
			_ = config.PersistAPIKey()
		}
	}
	if strings.TrimSpace(config.Get("api_key")) != "" {
		return
	}

	fmt.Println(console.Cream("  Open Cloud API key (meshes & animations)."))
	fmt.Println(console.Dim("  create.roblox.com/dashboard/credentials → Assets → Write"))
	for {
		key, err := console.Input("  API key: ")
		if err != nil {
			color.Error.Println(err)
			continue
		}
		key = strings.TrimSpace(key)
		if key == "" {
			color.Error.Println("API key is required.")
			continue
		}
		config.Set("api_key", key)
		if err := config.PersistAPIKey(); err != nil {
			color.Error.Println("Failed to save api key: ", err)
			continue
		}
		if err := config.Save(); err != nil {
			color.Error.Println("Failed to save config: ", err)
			continue
		}
		break
	}
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

func waitForInterrupt() {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, os.Interrupt, syscall.SIGTERM)
	<-ch
	console.ShowCursor()
	fmt.Println()
	fmt.Println(console.Dim("  Folk host stopped."))
}

func atoi64(s string) int64 {
	n, _ := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	return n
}
