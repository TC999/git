package patchwork

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type Series struct {
	PatchName string
	Level     string
	Garbage   string
}

// SeriesParse will parse series file
func SeriesParse(seriesPath string) ([]*Series, error) {
	var res []*Series

	f, err := os.Open(seriesPath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		currentLine := strings.TrimSpace(scanner.Text())

		// If the line is empty or start with # will ignore
		if len(currentLine) == 0 || strings.HasPrefix(currentLine, "#") {
			continue
		}

		s, err := processSeriesLine(currentLine)
		if err != nil {
			return nil, err
		}

		res = append(res, s)
	}

	return res, nil
}

func processSeriesLine(line string) (*Series, error) {
	var (
		patchName string
		level     string
		garbage   string
	)

	// Just ignore after '#' strings
	line = strings.Split(line, "#")[0]

	fields := strings.SplitN(line, " ", 3)

	if len(fields) == 1 {
		patchName = strings.TrimSpace(fields[0])
	}

	if len(fields) == 2 {
		patchName = strings.TrimSpace(fields[0])
		level = strings.TrimSpace(fields[1])
	}

	if len(fields) == 3 {
		patchName = strings.TrimSpace(fields[0])
		level = strings.TrimSpace(fields[1])
		garbage = strings.TrimSpace(fields[2])
	}

	if len(patchName) == 0 {
		return nil, fmt.Errorf("invalid patch name, cannot be parse, please check it again")
	}

	if len(garbage) > 0 {
		return nil, fmt.Errorf("series have garbage contents: %s", garbage)
	}

	return &Series{
		PatchName: patchName,
		Level:     level,
		Garbage:   garbage,
	}, nil

}
