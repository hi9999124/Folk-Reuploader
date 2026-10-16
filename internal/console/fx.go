package console

import (
	"fmt"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/kartFr/Asset-Reuploader/internal/color"
)

var (
	liveUI   bool
	liveLock sync.Mutex
)

func SetLiveUI(on bool) {
	liveLock.Lock()
	liveUI = on
	liveLock.Unlock()
}

func LiveUI() bool {
	liveLock.Lock()
	defer liveLock.Unlock()
	return liveUI
}

func Amber(s string) string {
	return "\x1b[38;2;232;168;88m" + s + "\x1b[0m"
}

func Dim(s string) string {
	return "\x1b[38;2;120;114;108m" + s + "\x1b[0m"
}

func Cream(s string) string {
	return "\x1b[38;2;240;234;224m" + s + "\x1b[0m"
}

func Green(s string) string {
	return "\x1b[38;2;110;220;160m" + s + "\x1b[0m"
}

func Red(s string) string {
	return "\x1b[38;2;240;120;110m" + s + "\x1b[0m"
}

func Banner() string {
	lines := []string{
		`  ███████╗ ██████╗ ██╗     ██╗  ██╗`,
		`  ██╔════╝██╔═══██╗██║     ██║ ██╔╝`,
		`  █████╗  ██║   ██║██║     █████╔╝ `,
		`  ██╔══╝  ██║   ██║██║     ██╔═██╗ `,
		`  ██║     ╚██████╔╝███████╗██║  ██╗`,
		`  ╚═╝      ╚═════╝ ╚══════╝╚═╝  ╚═╝`,
	}
	var b strings.Builder
	for i, line := range lines {
		shade := 200 - i*12
		if shade < 140 {
			shade = 140
		}
		b.WriteString(fmt.Sprintf("\x1b[38;2;%d;%d;88m%s\x1b[0m\n", shade, shade-40, line))
	}
	b.WriteString(Amber("              REUPLOADER") + Dim("  ·  v2.0.0") + "\n")
	return b.String()
}

func PlayIntro() {
	EnableVirtualTerminal()
	ClearScreen()
	HideCursor()
	defer ShowCursor()

	raw := strings.Split(strings.TrimRight(Banner(), "\n"), "\n")
	for i := 0; i <= len(raw); i++ {
		ClearScreen()
		fmt.Print(strings.Join(raw[:i], "\n"))
		if i < len(raw) {
			fmt.Print("\n")
		}
		time.Sleep(45 * time.Millisecond)
	}
	fmt.Println()
	fmt.Println(Dim("  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─"))
	Spin("warming Folk link", 700*time.Millisecond)
}

func Spin(label string, d time.Duration) {
	frames := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	deadline := time.Now().Add(d)
	i := 0
	HideCursor()
	defer ShowCursor()
	for time.Now().Before(deadline) {
		fmt.Printf("\r  %s %s", Amber(frames[i%len(frames)]), Cream(label))
		i++
		time.Sleep(55 * time.Millisecond)
	}
	fmt.Printf("\r  %s %s\n", Green("✔"), Cream(label))
}

func Box(title string, rows []string, width int) string {
	if width < 40 {
		width = 40
	}
	inner := width - 2
	var b strings.Builder
	b.WriteString(Amber("┌" + pad("", inner, "─") + "┐\n"))
	titleLine := " " + title
	b.WriteString(Amber("│") + Cream(pad(titleLine, inner, " ")) + Amber("│\n"))
	b.WriteString(Amber("├" + pad("", inner, "─") + "┤\n"))
	for _, row := range rows {
		b.WriteString(Amber("│") + Cream(pad(" "+row, inner, " ")) + Amber("│\n"))
	}
	b.WriteString(Amber("└" + pad("", inner, "─") + "┘"))
	return b.String()
}

func pad(s string, width int, with string) string {
	n := utf8.RuneCountInString(stripANSI(s))
	if n >= width {
		runes := []rune(stripANSI(s))
		return string(runes[:width])
	}
	return s + strings.Repeat(with, width-n)
}

func stripANSI(s string) string {
	var b strings.Builder
	skip := false
	for i := 0; i < len(s); i++ {
		if s[i] == 0x1b {
			skip = true
			continue
		}
		if skip {
			if s[i] == 'm' {
				skip = false
			}
			continue
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

func StatusDot(ok bool) string {
	if ok {
		return Green("● live")
	}
	return Red("● idle")
}

func FatalLine(err error) {
	color.Error.Println(err)
}
