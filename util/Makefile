TARGETS := patchwork
PKG := golang.aliyun-inc.com/agit/patchwork
GOBUILD := @go build -mod=vendor
GOTEST := @go test -mod=vendor

all: $(TARGETS)

patchwork: clean
	$(GOBUILD) -o $@ main/main.go

build: $(TARGETS)

test: ut

ut: $(TARGETS)
	$(GOTEST) $(PKG)/...

clean:
	@rm -f $(TARGETS)

.PHONY: all test ut clean

