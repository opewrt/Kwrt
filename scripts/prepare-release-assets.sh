#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: prepare-release-assets.sh [RELEASE_DIR] [TARGET]

Create GitHub Release upload assets from an install-release.sh directory:
  <release>/release-assets/
    packages-<target>.tar.zst
    targets-<target>.tar.zst
    selected firmware image, SDK, ImageBuilder, configs
    MANIFEST.refs, FILES.txt, SHA256SUMS, ASSETS.txt, ASSETS.sha256sums

Environment:
  GITHUB_ENV         When set, RELEASE_ASSETS and FIRMWARE are appended for CI
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	usage
	exit 0
fi

RELEASE_DIR="${1:-}"
TARGET="${2:-${TARGET:-unknown}}"

if [ -z "$RELEASE_DIR" ]; then
	usage >&2
	exit 1
fi

RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
ASSET_DIR="$RELEASE_DIR/release-assets"
rm -rf "$ASSET_DIR"
mkdir -p "$ASSET_DIR"

target_path="$(sed -n 's/^target_path=//p' "$RELEASE_DIR/MANIFEST.refs" | tail -n 1)"
if [ -z "$target_path" ] || [ ! -d "$RELEASE_DIR/$target_path" ]; then
	echo "Cannot find target_path in $RELEASE_DIR/MANIFEST.refs" >&2
	exit 1
fi
TARGET_DIR="$RELEASE_DIR/$target_path"

if [ -d "$RELEASE_DIR/packages" ]; then
	tar --use-compress-program="zstd -T0 -6" \
		-cf "$ASSET_DIR/packages-${TARGET}.tar.zst" \
		-C "$RELEASE_DIR" packages
fi

tar --use-compress-program="zstd -T0 -6" \
	-cf "$ASSET_DIR/targets-${TARGET}.tar.zst" \
	-C "$RELEASE_DIR" targets

copy_one() {
	local label="$1"
	shift
	local src
	for src in "$@"; do
		if [ -f "$src" ]; then
			cp -a "$src" "$ASSET_DIR/"
			return 0
		fi
	done
	echo "Missing release asset: $label" >&2
	return 1
}

shopt -s nullglob
copy_one "generic squashfs combined image" \
	"$TARGET_DIR"/*generic-squashfs-combined.img.gz
copy_one "SDK archive" \
	"$TARGET_DIR"/*sdk*.tar.zst
copy_one "ImageBuilder archive" \
	"$TARGET_DIR"/*imagebuilder*.tar.zst

for file in \
	"$RELEASE_DIR/$TARGET.config" \
	"$RELEASE_DIR/$TARGET.diffconfig" \
	"$RELEASE_DIR/${TARGET}_kernel.config" \
	"$RELEASE_DIR/MANIFEST.refs" \
	"$RELEASE_DIR/FILES.txt" \
	"$RELEASE_DIR/SHA256SUMS"; do
	if [ -f "$file" ]; then
		cp -a "$file" "$ASSET_DIR/"
	fi
done

if [ -f "$RELEASE_DIR/build.log" ]; then
	zstd -T0 -6 -f "$RELEASE_DIR/build.log" -o "$ASSET_DIR/build.log.zst"
fi

find "$ASSET_DIR" -maxdepth 1 -type f -size 0 -print -delete \
	| sed 's#^#Skipping empty release asset: #' >&2

(
	cd "$ASSET_DIR"
	find . -maxdepth 1 -type f ! -name ASSETS.sha256sums -printf '%P\n' \
		| sort > ASSETS.txt
	find . -maxdepth 1 -type f ! -name ASSETS.sha256sums -printf '%P\0' \
		| sort -z \
		| xargs -0 sha256sum > ASSETS.sha256sums
)

if [ -n "${GITHUB_ENV:-}" ]; then
	{
		echo "RELEASE_ASSETS=$ASSET_DIR"
		echo "FIRMWARE=$ASSET_DIR"
	} >> "$GITHUB_ENV"
fi

echo "$ASSET_DIR"
