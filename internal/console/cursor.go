package console

import "fmt"

func HideCursor() { fmt.Print("\x1b[?25l") }

func ShowCursor() { fmt.Print("\x1b[?25h") }

func HomeCursor() { fmt.Print("\x1b[H") }
