package config

import (
	"os"
	"strconv"
)

func GetEnvString(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func GetInt64(varName string, defaultValue int64) int64 {
	val, ok := os.LookupEnv(varName)
	if !ok {
		return defaultValue
	}

	iVal, err := strconv.ParseInt(val, 10, 64)
	if err != nil {
		return defaultValue
	}

	return iVal
}
