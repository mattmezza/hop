.PHONY: release check-version

# Release a new version
# Usage: make release name=v0.1.0
release: check-version
	@echo "Releasing $(name)..."
	@# Update version in hop script
	@sed -i 's/HOP_VERSION=".*"/HOP_VERSION="$(name:v%=%)"/' hop
	@# Commit the version bump
	@git add hop
	@git commit -m "Release $(name)"
	@# Create GitHub release (this also creates the tag)
	@gh release create $(name) --title "$(name)" --generate-notes
	@echo ""
	@echo "Release $(name) created!"
	@echo "GitHub Actions will build and attach the tarball automatically."

check-version:
	@test -n "$(name)" || (echo "Usage: make release name=vX.Y.Z" && exit 1)
	@echo "$(name)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || (echo "Error: Version must be in format vX.Y.Z (e.g., v0.1.0)" && exit 1)
