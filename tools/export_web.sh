#!/bin/sh
# Exports the web build to build/web, and with --publish commits it to the local `gh-pages`
# branch (an orphan branch holding only the build; push it yourself: git push origin gh-pages).
# Needs the 4.7.2 export templates (Godot → Manage Export Templates) and export_presets.cfg.
set -e
cd "$(dirname "$0")/.."
godot --headless --import
mkdir -p build/web
touch build/.gdignore  # Godot must not import the exported files.
godot --headless --export-release "Web" build/web/index.html
touch build/web/.nojekyll  # GitHub Pages: serve files as they are.
if [ "$1" = "--publish" ]; then
	source_commit=$(git rev-parse --short HEAD)
	if ! git rev-parse --verify -q gh-pages >/dev/null; then
		git worktree add --detach build/pages HEAD
		git -C build/pages checkout --orphan gh-pages
		git -C build/pages rm -rf -q .
	else
		git worktree add build/pages gh-pages
	fi
	rsync -a --delete --exclude .git build/web/ build/pages/
	git -C build/pages add -A
	git -C build/pages commit -q -m "Web build of $source_commit"
	git worktree remove --force build/pages
	echo "Committed to gh-pages. Publish with: git push origin gh-pages"
fi
