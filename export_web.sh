#!/usr/bin/env bash
# 웹 빌드 전용 익스포트.
# 원본 프로젝트는 읽기만 하고, ~/build/analog_horror_web 복사본에서만 4K 텍스처를
# size_limit=1024 로 낮춰 임포트/익스포트한다 (데스크톱용 원본 .import 는 그대로).
#
# 사용법: ./export_web.sh
# 환경변수: GODOT (Godot 4.7 바이너리), BUILD_DIR, OUT_DIR
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$HOME/build/analog_horror_web}"
OUT_DIR="${OUT_DIR:-$HOME/web/analog_horror}"
GODOT="${GODOT:-$HOME/.local/opt/godot/Godot_v4.7-stable_linux.x86_64}"
TEXTURE_LIMIT=1024

[ -x "$GODOT" ] || { echo "Godot 바이너리 없음: $GODOT" >&2; exit 1; }

echo "== rsync $SRC_DIR -> $BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"
# .godot 은 제외 + 보호(--delete 가 안 지움)라서 임포트 캐시가 다음 실행에도 남는다
rsync -a --delete \
	--exclude '/.godot/' --exclude '/.git/' --exclude '/.claude/' \
	"$SRC_DIR/" "$BUILD_DIR/"

echo "== 4K 텍스처 size_limit=$TEXTURE_LIMIT (복사본에만)"
while IFS= read -r -d '' import_file; do
	grep -q '^importer="texture"' "$import_file" || continue
	src="${import_file%.import}"
	[ -f "$src" ] || continue
	read -r w h < <(identify -ping -format '%w %h\n' "$src" 2>/dev/null | head -1) || continue
	if [ "${w:-0}" -ge 4096 ] || [ "${h:-0}" -ge 4096 ]; then
		sed -i "s/^process\/size_limit=.*/process\/size_limit=$TEXTURE_LIMIT/" "$import_file"
		echo "  ${src#"$BUILD_DIR/"} (${w}x${h})"
	fi
done < <(find "$BUILD_DIR" -name '*.import' -not -path "$BUILD_DIR/.godot/*" -print0)

echo "== import"
timeout 1800 "$GODOT" --headless --path "$BUILD_DIR" --import

echo "== export -> $OUT_DIR/index.html"
timeout 1800 "$GODOT" --headless --path "$BUILD_DIR" --export-release "Web" "$OUT_DIR/index.html"

du -sh "$OUT_DIR"/index.pck "$OUT_DIR"/index.wasm
echo "확인 링크: https://pop-os.tail159d07.ts.net/analog_horror/?v=$(git -C "$SRC_DIR" rev-parse --short HEAD)"
