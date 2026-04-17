RELEASE_BUILD=./.build/apple/Products/Release
EXECUTABLE=rems
ARCHIVE=$(EXECUTABLE).tar.gz

.PHONY: clean build-release package update-nix-config

build-release:
	swift build --configuration release -Xswiftc -warnings-as-errors --arch arm64 --arch x86_64

package: build-release
	$(RELEASE_BUILD)/$(EXECUTABLE) --generate-completion-script zsh > _rems
	tar -pvczf $(ARCHIVE) _rems -C $(RELEASE_BUILD) $(EXECUTABLE)
	tar -zxvf $(ARCHIVE)
	@shasum -a 256 $(ARCHIVE)
	@shasum -a 256 $(EXECUTABLE)
	rm $(EXECUTABLE) _rems

clean:
	rm -f $(EXECUTABLE) $(ARCHIVE) _rems
	swift package clean

update-nix-config:
	cd "$$(ghq root)/github.com/ivankovnatsky/nix-config" && \
	NIX_CONFIG="access-tokens = github.com=$$(gh auth token)" nix flake update rems --commit-lock-file
