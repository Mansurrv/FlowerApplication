package utils

import (
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

const (
	DefaultLimit = int64(20)
	MaxLimit     = int64(100)
)

type Pagination struct {
	Page  int64
	Limit int64
}

func parseNumber(value string, fallback int64) int64 {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return fallback
	}
	return parsed
}

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

func ParsePagination(c *gin.Context, defaultLimit int64, maxLimit int64) (bool, *Pagination, int64) {
	pageRaw := c.Query("page")
	limitRaw := c.Query("limit")
	if pageRaw == "" && limitRaw == "" {
		return false, nil, 0
	}
	page := parseNumber(pageRaw, 1)
	if page < 1 {
		page = 1
	}
	limit := parseNumber(limitRaw, defaultLimit)
	if limit < 1 {
		limit = defaultLimit
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	skip := (page - 1) * limit
	return true, &Pagination{Page: page, Limit: limit}, skip
}

func BuildFindOptions(c *gin.Context, defaultSort string) (*options.FindOptions, *Pagination) {
	findOptions := options.Find()

	sort := parseSort(c.Query("sort"), defaultSort)
	if sort != nil {
		findOptions.SetSort(sort)
	}

	projection := parseFields(c.Query("fields"))
	if projection != nil {
		findOptions.SetProjection(projection)
	}

	paginate, pagination, skip := ParsePagination(c, DefaultLimit, MaxLimit)
	if paginate && pagination != nil {
		findOptions.SetSkip(skip)
		findOptions.SetLimit(pagination.Limit)
		return findOptions, pagination
	}

	return findOptions, nil
}

func BuildPaginationMeta(total int64, page int64, limit int64) bson.M {
	pages := int64(0)
	if limit > 0 {
		pages = (total + limit - 1) / limit
	}
	return bson.M{
		"total": total,
		"page":  page,
		"limit": limit,
		"pages": pages,
	}
}
