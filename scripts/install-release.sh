#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: install-release.sh [OPENWRT_DIR] [RELEASE_ROOT] [TARGET]

Install OpenWrt build outputs into a stable release layout:
  <release>/<timestamp>-<target>/
    targets/<board>/<subtarget>/
    packages/<arch>/
    *.config, *.diffconfig, *_kernel.config, build.log
    MANIFEST.refs, FILES.txt, SHA256SUMS

Environment:
  RELEASE_DATE       Override timestamp, default: current YYYYMMDD-HHMMSS
  PACKAGE_ARCH       Override package arch copied from bin/packages/<arch>
  GITHUB_ENV         When set, FIRMWARE and RELEASE_DIR are appended for CI
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	usage
	exit 0
fi

OPENWRT_DIR="${1:-$PWD}"
RELEASE_ROOT="${2:-${OPENWRT_DIR}/../release-kwrt}"
TARGET="${3:-${TARGET:-unknown}}"
RELEASE_DATE="${RELEASE_DATE:-$(date +%Y%m%d-%H%M%S)}"

OPENWRT_DIR="$(cd "$OPENWRT_DIR" && pwd)"
mkdir -p "$RELEASE_ROOT"
RELEASE_ROOT="$(cd "$RELEASE_ROOT" && pwd)"

TARGETS_ROOT="${OPENWRT_DIR}/bin/targets"
PACKAGES_ROOT="${OPENWRT_DIR}/bin/packages"
test -d "$TARGETS_ROOT"

TARGET_DIR_COUNT="$(find "$TARGETS_ROOT" -mindepth 2 -maxdepth 2 -type d | wc -l)"
if [ "$TARGET_DIR_COUNT" -eq 1 ]; then
	TARGET_OUT_DIR="$(find "$TARGETS_ROOT" -mindepth 2 -maxdepth 2 -type d -print -quit)"
else
	case "$TARGET" in
		x86_64) TARGET_OUT_DIR="${TARGETS_ROOT}/x86/64" ;;
		x86_generic) TARGET_OUT_DIR="${TARGETS_ROOT}/x86/generic" ;;
		*) TARGET_OUT_DIR="$(find "$TARGETS_ROOT" -mindepth 2 -maxdepth 2 -type d -print -quit)" ;;
	esac
fi
test -d "$TARGET_OUT_DIR"

TARGET_REL="${TARGET_OUT_DIR#${TARGETS_ROOT}/}"
PACKAGE_ARCH="${PACKAGE_ARCH:-}"
if [ -n "$PACKAGE_ARCH" ] && [ ! -d "$PACKAGES_ROOT/$PACKAGE_ARCH" ]; then
	PACKAGE_ARCH=""
fi
if [ -z "$PACKAGE_ARCH" ] && [ -d "$PACKAGES_ROOT" ]; then
	case "$TARGET" in
		x86_64) PACKAGE_ARCH="x86_64" ;;
		x86_generic) PACKAGE_ARCH="i386_pentium4" ;;
		*) PACKAGE_ARCH="$(find "$PACKAGES_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | head -n 1)" ;;
	esac
fi

RELEASE_DIR="${RELEASE_ROOT}/${RELEASE_DATE}-${TARGET}"
mkdir -p "$RELEASE_DIR/targets/$TARGET_REL"
cp -a "$TARGET_OUT_DIR"/. "$RELEASE_DIR/targets/$TARGET_REL"/

if [ -n "$PACKAGE_ARCH" ] && [ -d "$PACKAGES_ROOT/$PACKAGE_ARCH" ]; then
	mkdir -p "$RELEASE_DIR/packages/$PACKAGE_ARCH"
	cp -a "$PACKAGES_ROOT/$PACKAGE_ARCH"/. "$RELEASE_DIR/packages/$PACKAGE_ARCH"/
fi

cp -f "$OPENWRT_DIR/.config" "$RELEASE_DIR/${TARGET}.config" 2>/dev/null || true
if [ -x "$OPENWRT_DIR/scripts/diffconfig.sh" ]; then
	"$OPENWRT_DIR/scripts/diffconfig.sh" > "$RELEASE_DIR/${TARGET}.diffconfig" 2>/dev/null || true
fi
if [ ! -s "$RELEASE_DIR/${TARGET}.diffconfig" ]; then
	cp -f "$OPENWRT_DIR/kwrt-${TARGET}.diffconfig" "$RELEASE_DIR/${TARGET}.diffconfig" 2>/dev/null || true
	cp -f "$OPENWRT_DIR/kwrt-x86_64.diffconfig" "$RELEASE_DIR/${TARGET}.diffconfig" 2>/dev/null || true
fi
cp -f "$OPENWRT_DIR/build.log" "$RELEASE_DIR/build.log" 2>/dev/null || true

kernel_cfg="$(find "$OPENWRT_DIR"/build_dir/target-* -path '*/linux-*/.config' -print -quit 2>/dev/null || true)"
if [ -n "$kernel_cfg" ]; then
	cp -f "$kernel_cfg" "$RELEASE_DIR/${TARGET}_kernel.config"
fi

{
	echo "release_dir=$RELEASE_DIR"
	echo "release_date=$RELEASE_DATE"
	echo "target=$TARGET"
	echo "target_path=targets/$TARGET_REL"
	[ -n "$PACKAGE_ARCH" ] && echo "package_arch=$PACKAGE_ARCH"
	echo "openwrt=$(git -C "$OPENWRT_DIR" rev-parse HEAD 2>/dev/null || true)"
	for feed in packages luci routing telephony kiddin9; do
		if [ -d "$OPENWRT_DIR/feeds/$feed/.git" ]; then
			echo "feed.${feed}=$(git -C "$OPENWRT_DIR/feeds/$feed" rev-parse HEAD)"
		elif [ -d "$OPENWRT_DIR/feeds/$feed" ]; then
			echo "feed.${feed}=local-directory"
		fi
	done
	echo "opewrt-lede=${LEDE_REF:-19978f14dceb8a3e6e63c8eb1d30e2052738add3}"
	echo "immortalwrt=${IMMORTALWRT_REF:-a5d949fc9e6a7701a155ea1a10eacc130f55e8b7}"
	echo "kwrt-packages=${KWRT_PACKAGES_REF:-f5cbc4bdd62ad549f587e8753e36aa4c307cfb2f}"
} > "$RELEASE_DIR/MANIFEST.refs"

(cd "$RELEASE_DIR" && find . -mindepth 1 -printf '%P\n' | sort > FILES.txt)
(cd "$RELEASE_DIR" && rm -f SHA256SUMS && find . -type f ! -name SHA256SUMS -printf '%P\0' | sort -z | xargs -0 sha256sum > SHA256SUMS)

if [ -n "${GITHUB_ENV:-}" ]; then
	{
		echo "RELEASE_DIR=$RELEASE_DIR"
		echo "FIRMWARE=$RELEASE_DIR/targets/$TARGET_REL"
	} >> "$GITHUB_ENV"
fi

echo "$RELEASE_DIR"
