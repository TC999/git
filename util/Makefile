TARGETS := patchwork
FIND := find
PKG := golang.aliyun-inc.com/agit/patchwork
GOBUILD := @go build -mod=vendor
GOTEST := @go test -mod=vendor

SOURCES_CMD = ( \
        git ls-files \
		'*.go' \
		':!vendor' \
                2>/dev/null || \
        $(FIND) . \
                \( -name .git -type d -prune \) \
                -o \( -name vendor -type d -prune \) \
                -o \( -name '*.go' -type f -print \) \
                | sed -e 's|^\./||' \
        )
FOUND_SOURCE_FILES := $(shell $(SOURCES_CMD))

all: $(TARGETS)

patchwork: $(FOUND_SOURCE_FILES)
	$(GOBUILD) -o $@ main/main.go

test: ut

ut: $(TARGETS)
	$(GOTEST) $(PKG)/...
	@make -C test

clean:
	@rm -f $(TARGETS)

.PHONY: all test ut clean

