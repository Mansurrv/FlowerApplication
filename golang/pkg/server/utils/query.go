package utils

import (
	"strings"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func parseSort(sort string, defaultSort string) bson.D {
	value := strings.TrimSpace(sort)
	if value == "" {
		value = strings.TrimSpace(defaultSort)
	}
	if value == "" {
		return nil
	}
	parts := strings.FieldsFunc(value, func(r rune) bool {
		return r == ',' || r == ' '
	})
	var sortDoc bson.D
	for _, part := range parts {
		field := strings.TrimSpace(part)
		if field == "" {
			continue
		}
		direction := int32(1)
		if strings.HasPrefix(field, "-") {
			direction = -1
			field = strings.TrimPrefix(field, "-")
		}
		sortDoc = append(sortDoc, bson.E{Key: field, Value: direction})
	}
	if len(sortDoc) == 0 {
		return nil
	}
	return sortDoc
}

func parseFields(fields string) bson.M {
	value := strings.TrimSpace(fields)
	if value == "" {
		return nil
	}
	parts := strings.Split(value, ",")
	projection := bson.M{}
	useExclude := false
	for _, part := range parts {
		field := strings.TrimSpace(part)
		if field == "" {
			continue
		}
		if strings.HasPrefix(field, "-") {
			useExclude = true
			field = strings.TrimPrefix(field, "-")
		}
		projection[field] = 1
	}
	if useExclude {
		for k := range projection {
			projection[k] = 0
		}
	}
	if len(projection) == 0 {
		return nil
	}
	return projection
}

func BuildFindOptions(c *gin.Context, defaultSort string) *options.FindOptions {
	findOptions := options.Find()

	sort := parseSort(c.Query("sort"), defaultSort)
	if sort != nil {
		findOptions.SetSort(sort)
	}

	projection := parseFields(c.Query("fields"))
	if projection != nil {
		findOptions.SetProjection(projection)
	}

	return findOptions
}
