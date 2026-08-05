#!/usr/bin/env bash
# mksheet.sh - turn a reference image (AI-generated, ripped or hand-drawn) into
# a PMD-style <Name>-Anim.png sheet that SpriteAnimation.qml can play.
#
# It cuts the source into a grid, keeps only the rows you ask for, floodfills
# the background away, scales every frame by ONE shared factor (so directions
# never change size mid-animation), lays each frame into a fixed WxH cell and
# appends everything into a single sheet. With --mirror it also turns the 5
# drawn views (S, SE, E, NE, N) into the 8 direction rows PMD expects.
#
# Requires: ImageMagick 7 (magick).

set -euo pipefail

die()  { printf 'mksheet: %s\n' "$*" >&2; exit 1; }
note() { printf 'mksheet: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
usage: mksheet.sh --src IMG --out DIR --name NAME --grid RxC [options]

required
  --src IMG        reference image (png/jpg/webp)
  --out DIR        sprite pack directory, e.g. assets/sprites/belo.
                   A comma-separated list fans out: one directory per --pick
                   row, so one reference image holding several pets writes
                   every pet's sheet in a single run.
  --name NAME      animation name -> writes <DIR>/<NAME>-Anim.png
  --grid RxC       how the source is laid out: R rows x C columns.
                   C may be "auto" to split each row by its empty gaps.

picking
  --pick LIST      1-indexed source rows to use, in output order (default: all)
                   e.g. --pick 3,1,2
  --take LIST      1-indexed frames to keep inside each picked row, in output
                   order (default: all). With --grid RxC these are columns;
                   with RxauTo they are the sprites found in the row.

frame
  --frame WxH      output frame size, default 32x32 (use 48x48 for lying poses)
  --fill F         how much of the frame the biggest sprite fills, default 0.95
  --anchor A       bottom (default) or center - where the sprite sits in the cell
  --align A        each (default) re-centers every frame on its own bounding box
                   (steady, best for messy AI grids);
                   union keeps each frame's offset inside the row's shared box
                   (preserves bobbing, needs a well-aligned source)

background
  --bg COLOR       background to remove, default auto (samples pixel 0,0)
  --fuzz N%        background tolerance, default 14%
  --inset N        pixels shaved off each cell before cutting, default auto
                   (~1% of the cell - eats grid lines drawn by the AI)
  --alpha-thr N%   hardens the anti-aliased edge into pixel-art alpha, default 50%
  --min-blob R     erase leftovers smaller than R of the sprite - grid lines,
                   jpeg specks, a neighbour's paw. Default 0.15, 0 disables.
  --colors N       quantize the final sheet to N colors (0 = off)

output shape
  --mirror         input rows are the 5 views S,SE,E,NE,N (or 3: S,E,N) and the
                   sheet is expanded to the 8 PMD direction rows by flopping
  --durations LIST per-frame durations for AnimData.xml, e.g. 3,3,3,3 (default 4)
  --no-xml         do not create/update <DIR>/AnimData.xml
  --preview        also write a 6x preview PNG and print its path
  --inspect        only draw the grid over the source so you can check rows/cols

example
  # walk: AI sheet with 5 view-rows x 4 frames -> 8-row PMD sheet
  mksheet.sh --src ref.png --out assets/sprites/belo --name Walk \
             --grid 5x4 --mirror --durations 3,3,3,3
  # sleep: the lying pose in column 1 of source row 2, bigger frame, single row
  mksheet.sh --src ref.png --out assets/sprites/belo --name Sleep \
             --grid 3xauto --pick 2 --take 1 --frame 48x48 --durations 40
  # one image, one pet per row -> one Sleep sheet per pack directory
  mksheet.sh --src pack.png --name Sleep --grid 3x2 --pick 1,2,3 \
             --out assets/sprites/belo,assets/sprites/lua,assets/sprites/kitty \
             --frame 48x48 --durations 40,40
EOF
}

# --- defaults ---------------------------------------------------------------
SRC=""; OUT=""; NAME=""; GRID=""; PICK="all"; TAKE="all"
FRAME="32x32"; FILL="0.95"; ANCHOR="bottom"; ALIGN="each"
BG="auto"; FUZZ="14%"; INSET="auto"; ALPHA_THR="50%"; COLORS=0; MIN_BLOB="0.15"
MIRROR=0; DURATIONS=""; WRITE_XML=1; PREVIEW=0; INSPECT=0

ARGV=("$@")
while [[ $# -gt 0 ]]; do
    case $1 in
        --src)        SRC=$2; shift 2 ;;
        --out)        OUT=$2; shift 2 ;;
        --name)       NAME=$2; shift 2 ;;
        --grid)       GRID=$2; shift 2 ;;
        --pick)       PICK=$2; shift 2 ;;
        --take)       TAKE=$2; shift 2 ;;
        --frame)      FRAME=$2; shift 2 ;;
        --fill)       FILL=$2; shift 2 ;;
        --anchor)     ANCHOR=$2; shift 2 ;;
        --align)      ALIGN=$2; shift 2 ;;
        --bg)         BG=$2; shift 2 ;;
        --fuzz)       FUZZ=$2; shift 2 ;;
        --inset)      INSET=$2; shift 2 ;;
        --alpha-thr)  ALPHA_THR=$2; shift 2 ;;
        --min-blob)   MIN_BLOB=$2; shift 2 ;;
        --colors)     COLORS=$2; shift 2 ;;
        --durations)  DURATIONS=$2; shift 2 ;;
        --mirror)     MIRROR=1; shift ;;
        --no-xml)     WRITE_XML=0; shift ;;
        --preview)    PREVIEW=1; shift ;;
        --inspect)    INSPECT=1; shift ;;
        -h|--help)    usage; exit 0 ;;
        *)            die "unknown option: $1 (try --help)" ;;
    esac
done

command -v magick >/dev/null || die "ImageMagick 7 (magick) not found"
[[ -n $SRC ]] || { usage >&2; exit 1; }
[[ -f $SRC ]] || die "source not found: $SRC"
[[ -n $GRID ]] || die "--grid RxC is required"
(( INSPECT )) || [[ -n $OUT && -n $NAME ]] || die "--out and --name are required"

IFS=x read -r ROWS COLS <<<"$GRID"
[[ $ROWS =~ ^[0-9]+$ && $ROWS -gt 0 ]] || die "bad --grid rows: $GRID"
[[ $COLS == auto || ( $COLS =~ ^[0-9]+$ && $COLS -gt 0 ) ]] || die "bad --grid cols: $GRID"

# --- fan out: one reference image, one pet per row ---------------------------
# "--out A,B,C --pick 1,2,3" is just this script run once per pair, so re-invoke
# ourselves instead of threading a second dimension through every step below.
# Each pet keeps its own shared scale, exactly as if it had its own image.
if [[ $OUT == *,* ]] && (( ! INSPECT )); then
    IFS=, read -r -a OUT_ARR <<<"$OUT"
    if [[ $PICK == all ]]; then
        FAN_PICK=(); for ((r=1; r<=ROWS; r++)); do FAN_PICK+=("$r"); done
    else
        IFS=, read -r -a FAN_PICK <<<"$PICK"
    fi
    (( ${#OUT_ARR[@]} == ${#FAN_PICK[@]} )) ||
        die "--out lists ${#OUT_ARR[@]} directories but --pick has ${#FAN_PICK[@]} rows"
    # everything except --out/--pick, which the children get one at a time
    passthru=(); i=0
    while (( i < ${#ARGV[@]} )); do
        case ${ARGV[i]} in
            --out|--pick) i=$(( i + 2 )) ;;
            *)            passthru+=("${ARGV[i]}"); i=$(( i + 1 )) ;;
        esac
    done
    for k in "${!OUT_ARR[@]}"; do
        note "--- ${OUT_ARR[k]} (source row ${FAN_PICK[k]})"
        "$0" "${passthru[@]}" --out "${OUT_ARR[k]}" --pick "${FAN_PICK[k]}"
    done
    exit 0
fi

if [[ $FRAME == *x* ]]; then IFS=x read -r FRAME_W FRAME_H <<<"$FRAME"
else FRAME_W=$FRAME; FRAME_H=$FRAME; fi

case $ANCHOR in bottom) GRAVITY=South ;; center) GRAVITY=Center ;; *) die "bad --anchor: $ANCHOR" ;; esac
case $ALIGN in each|union) ;; *) die "bad --align: $ALIGN" ;; esac

read -r SRC_W SRC_H <<<"$(magick identify -format '%w %h' "${SRC}[0]")"
CELL_H=$(( SRC_H / ROWS ))
(( CELL_H > 0 )) || die "source is smaller than the requested grid"
if [[ $COLS == auto ]]; then CELL_W=$SRC_W; else CELL_W=$(( SRC_W / COLS )); fi

if [[ $INSET == auto ]]; then
    m=$(( CELL_H < CELL_W ? CELL_H : CELL_W ))
    INSET=$(( m / 100 )); (( INSET < 1 )) && INSET=1
fi

if [[ $BG == auto ]]; then
    # the most frequent color, not p{0,0}: AI sheets often open with a grid line
    # or a drop shadow in the corner, but the background always dominates
    BG=$(magick "${SRC}[0]" -depth 8 -format %c histogram:info:- |
         sort -rn | awk 'NR == 1 && match($0, /#[0-9A-Fa-f]{6}/) { print substr($0, RSTART, RLENGTH) }')
    [[ -n $BG ]] || die "could not detect the background, pass --bg COLOR"
    note "background detected: $BG"
fi

if [[ $PICK == all ]]; then
    PICK_ARR=(); for ((r=1; r<=ROWS; r++)); do PICK_ARR+=("$r"); done
else
    IFS=, read -r -a PICK_ARR <<<"$PICK"
fi
for r in "${PICK_ARR[@]}"; do
    [[ $r =~ ^[0-9]+$ ]] && (( r >= 1 && r <= ROWS )) || die "--pick: row $r is outside 1..$ROWS"
done

TAKE_ARR=()
if [[ $TAKE != all ]]; then
    IFS=, read -r -a TAKE_ARR <<<"$TAKE"
    for t in "${TAKE_ARR[@]}"; do
        [[ $t =~ ^[0-9]+$ ]] && (( t >= 1 )) || die "--take: bad frame index '$t'"
    done
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/mksheet.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# --- inspect: draw the grid over the source and stop -------------------------
if (( INSPECT )); then
    draw=""
    for ((r=0; r<ROWS; r++)); do
        y=$(( r * SRC_H / ROWS )); y2=$(( (r + 1) * SRC_H / ROWS ))
        draw+=" rectangle 1,$((y+1)) $((SRC_W-2)),$((y2-2))"
        if [[ $COLS != auto ]]; then
            for ((c=1; c<COLS; c++)); do
                x=$(( c * SRC_W / COLS ))
                draw+=" line $x,$y $x,$y2"
            done
        fi
    done
    labels=""
    for ((r=0; r<ROWS; r++)); do
        labels+=" -annotate +6+$(( r * SRC_H / ROWS + 26 )) row$((r+1))"
    done
    OVERLAY="$TMP/inspect.png"; OVERLAY_KEEP="${TMPDIR:-/tmp}/mksheet-inspect.png"
    # shellcheck disable=SC2086
    magick "${SRC}[0]" -fill none -stroke red -strokewidth 2 -draw "$draw" \
        -stroke none -fill red -pointsize 22 $labels "$OVERLAY"
    cp "$OVERLAY" "$OVERLAY_KEEP"
    printf '%s\n' "$OVERLAY_KEEP"
    exit 0
fi

# --- 1. cut the picked rows into background-free cells -----------------------
# crop_bg GEOMETRY DEST - crops the source and floodfills the background away.
# The 1px border makes every edge of the crop one connected background region,
# so a single floodfill clears all four sides while white *inside* the sprite
# (a belly, an eye highlight) survives.
crop_bg() {
    magick "${SRC}[0]" -crop "$1" +repage -alpha set \
        -bordercolor "$BG" -border 1 -fuzz "$FUZZ" \
        -fill none -draw 'alpha 0,0 floodfill' \
        -shave 1x1 +repage "$2"
}

# blobs FILE - opaque connected components, biggest first, as "area w h x y".
blobs() {
    magick "$1" -alpha extract -threshold 50% \
        -define connected-components:verbose=true \
        -connected-components 8 null: 2>&1 |
    awk '$NF ~ /255,255,255|gray\(255\)|white/ {
             split($2, b, /[x+]/); print $4 + 0, b[1], b[2], b[3], b[4] }' |
    sort -rn
}

# clean_frame FILE - the floodfill only clears background connected to the cell
# border, so grid lines and jpeg specks survive as separate blobs and poison the
# bounding box. Drop every blob smaller than MIN_BLOB of the biggest one.
clean_frame() {
    local f=$1 area thr
    area=$(blobs "$f" | awk 'NR == 1 { print $1 + 0 }')
    (( area > 0 )) || return 0
    thr=$(awk -v a="$area" -v r="$MIN_BLOB" 'BEGIN { printf "%d", a * r }')
    (( thr > 0 )) || return 0
    magick "$f" \
        \( +clone -alpha extract -threshold 50% \
           -define connected-components:mean-color=true \
           -define connected-components:area-threshold="$thr" \
           -connected-components 8 \) \
        -alpha off -compose CopyOpacity -composite "$f"
}

# column_runs BAND WIDTH - prints "x width" for each horizontal run of non-empty
# columns, i.e. one line per sprite found in the band.
column_runs() {
    magick "$1" -alpha extract -scale "${2}x1!" -depth 8 txt:- |
        sed -n 's/^\([0-9]\+\),0: (\([0-9]\+\).*/\1 \2/p' |
        awk -v minw=$(( $2 / 100 + 1 )) '
            { occ = ($2 > 6); x = $1
              if (occ && !run) { run = 1; start = x }
              else if (!occ && run) { run = 0; if (x - start >= minw) print start, x - start } }
            END { if (run && x - start + 1 >= minw) print start, x - start + 1 }'
}

declare -a ROW_FILES=()
oi=0
for r in "${PICK_ARR[@]}"; do
    # exact band edges, so the remainder of an uneven split is not lost at the
    # bottom of the image
    y0=$(( (r - 1) * SRC_H / ROWS )); y1=$(( r * SRC_H / ROWS ))
    y=$(( y0 + INSET )); h=$(( y1 - y0 - 2 * INSET ))
    files=()
    if [[ $COLS == auto ]]; then
        band="$TMP/band${oi}.png"
        crop_bg "${SRC_W}x${h}+0+${y}" "$band"
        i=0
        while read -r rx rw; do
            [[ -n $rx ]] || continue
            f="$TMP/c${oi}_${i}.png"
            magick "$band" -crop "${rw}x${h}+${rx}+0" +repage "$f"
            files+=("$f"); i=$(( i + 1 ))
        done < <(column_runs "$band" "$SRC_W")
        (( ${#files[@]} )) || die "row $r: no sprite found (try --fuzz or --inset)"
        note "row $r: found ${#files[@]} frame(s)"
    else
        for ((c=0; c<COLS; c++)); do
            f="$TMP/c${oi}_${c}.png"
            x0=$(( c * SRC_W / COLS )); x1=$(( (c + 1) * SRC_W / COLS ))
            crop_bg "$(( x1 - x0 - 2*INSET ))x${h}+$(( x0 + INSET ))+${y}" "$f"
            files+=("$f")
        done
    fi
    if (( ${#TAKE_ARR[@]} )); then
        kept=()
        for t in "${TAKE_ARR[@]}"; do
            (( t <= ${#files[@]} )) || die "row $r: --take $t but only ${#files[@]} frame(s) here"
            kept+=("${files[t-1]}")
        done
        files=("${kept[@]}")
    fi
    if [[ $MIN_BLOB != 0 ]]; then
        for f in "${files[@]}"; do clean_frame "$f"; done
    fi
    ROW_FILES[oi]="${files[*]}"
    oi=$(( oi + 1 ))
done
NROWS=$oi

# --- 2. bounding boxes + one shared scale ------------------------------------
declare -A BOX=()
MAXW=1; MAXH=1
for ((oi=0; oi<NROWS; oi++)); do
    read -r -a files <<<"${ROW_FILES[oi]}"
    umin_x=999999; umin_y=999999; umax_x=0; umax_y=0
    declare -a bw=() bh=() bx=() by=()
    for ((i=0; i<${#files[@]}; i++)); do
        # the biggest blob is the sprite; -trim would also swallow whatever
        # leftover pixel sits in a corner
        read -r _ tw th tx ty <<<"$(blobs "${files[i]}" | awk 'NR == 1')"
        tw=${tw:-0}; th=${th:-0}; tx=${tx:-0}; ty=${ty:-0}
        if (( tw <= 1 && th <= 1 )); then
            note "row $((oi+1)) frame $((i+1)) is empty after background removal"
            tw=$CELL_W; th=$CELL_H; tx=0; ty=0
        fi
        bw[i]=$tw; bh[i]=$th; bx[i]=$tx; by[i]=$ty
        (( tx < umin_x )) && umin_x=$tx
        (( ty < umin_y )) && umin_y=$ty
        (( tx + tw > umax_x )) && umax_x=$(( tx + tw ))
        (( ty + th > umax_y )) && umax_y=$(( ty + th ))
    done
    for ((i=0; i<${#files[@]}; i++)); do
        if [[ $ALIGN == union ]]; then
            w=$(( umax_x - umin_x )); h=$(( umax_y - umin_y )); x=$umin_x; y=$umin_y
        else
            w=${bw[i]}; h=${bh[i]}; x=${bx[i]}; y=${by[i]}
        fi
        BOX["${oi}_${i}"]="${w}x${h}+${x}+${y}"
        (( w > MAXW )) && MAXW=$w
        (( h > MAXH )) && MAXH=$h
    done
done

SCALE=$(awk -v mw="$MAXW" -v mh="$MAXH" -v fw="$FRAME_W" -v fh="$FRAME_H" -v fill="$FILL" \
    'BEGIN { a = fw*fill/mw; b = fh*fill/mh; s = (a < b) ? a : b; printf "%.4f", s*100 }')
note "shared scale: ${SCALE}% (largest sprite ${MAXW}x${MAXH} -> frame ${FRAME_W}x${FRAME_H})"

# --- 3. render every frame into its fixed cell -------------------------------
declare -a OUT_FILES=()
for ((oi=0; oi<NROWS; oi++)); do
    read -r -a files <<<"${ROW_FILES[oi]}"
    rendered=()
    for ((i=0; i<${#files[@]}; i++)); do
        f="$TMP/f${oi}_${i}.png"
        magick "${files[i]}" -crop "${BOX[${oi}_${i}]}" +repage \
            -filter Box -resize "${SCALE}%" \
            -channel A -threshold "$ALPHA_THR" +channel \
            -background none -gravity "$GRAVITY" -extent "${FRAME_W}x${FRAME_H}" +repage "$f"
        rendered+=("$f")
    done
    OUT_FILES[oi]="${rendered[*]}"
done

# --- 4. expand the drawn views into the 8 PMD direction rows -----------------
# PMD row order: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW, and the western half is
# just the eastern half flopped.
declare -a SHEET_ROWS=()
if (( MIRROR )); then
    case $NROWS in
        5) MAP=(0 1 2 3 4 3f 2f 1f) ;;
        3) MAP=(0 1 1 1 2 1f 1f 1f) ;;
        *) die "--mirror needs 5 picked rows (S,SE,E,NE,N) or 3 (S,E,N), got $NROWS" ;;
    esac
else
    MAP=(); for ((oi=0; oi<NROWS; oi++)); do MAP+=("$oi"); done
fi

for ((k=0; k<${#MAP[@]}; k++)); do
    spec=${MAP[k]}; src_row=${spec%f}; flop=0
    [[ $spec == *f ]] && flop=1
    read -r -a rendered <<<"${OUT_FILES[src_row]}"
    row=()
    for ((i=0; i<${#rendered[@]}; i++)); do
        if (( flop )); then
            g="$TMP/m${k}_${i}.png"
            magick "${rendered[i]}" -flop "$g"
            row+=("$g")
        else
            row+=("${rendered[i]}")
        fi
    done
    SHEET_ROWS[k]="${row[*]}"
done

# --- 5. pad rows to a rectangle and assemble ---------------------------------
MAXF=0
for ((k=0; k<${#SHEET_ROWS[@]}; k++)); do
    read -r -a row <<<"${SHEET_ROWS[k]}"
    (( ${#row[@]} > MAXF )) && MAXF=${#row[@]}
done

strips=()
for ((k=0; k<${#SHEET_ROWS[@]}; k++)); do
    read -r -a row <<<"${SHEET_ROWS[k]}"
    if (( ${#row[@]} < MAXF )); then
        note "row $((k+1)) has ${#row[@]}/$MAXF frames - padding with its last frame"
        while (( ${#row[@]} < MAXF )); do row+=("${row[-1]}"); done
    fi
    s="$TMP/strip${k}.png"
    magick "${row[@]}" +append "$s"
    strips+=("$s")
done

mkdir -p "$OUT"
SHEET="$OUT/${NAME}-Anim.png"
if (( COLORS > 0 )); then
    magick "${strips[@]}" -append -background none -alpha on +dither -colors "$COLORS" "$SHEET"
else
    magick "${strips[@]}" -append "$SHEET"
fi
note "wrote $SHEET (${MAXF} frames x ${#strips[@]} rows, ${FRAME_W}x${FRAME_H} each)"

# --- 6. AnimData.xml ---------------------------------------------------------
if (( WRITE_XML )); then
    IFS=, read -r -a durs <<<"${DURATIONS:-}"
    block="$TMP/anim.xml"
    {
        printf '    <Anim>\n      <Name>%s</Name>\n' "$NAME"
        printf '      <FrameWidth>%s</FrameWidth>\n      <FrameHeight>%s</FrameHeight>\n' "$FRAME_W" "$FRAME_H"
        printf '      <Durations>\n'
        last=4
        for ((i=0; i<MAXF; i++)); do
            d=${durs[i]:-$last}; last=$d
            printf '        <Duration>%s</Duration>\n' "$d"
        done
        printf '      </Durations>\n    </Anim>\n'
    } >"$block"

    XML="$OUT/AnimData.xml"
    if [[ -f $XML ]]; then
        awk -v name="$NAME" -v blockfile="$block" '
            /<Anim>/ { inblock = 1; buf = "" }
            inblock {
                buf = buf $0 "\n"
                if ($0 ~ /<\/Anim>/) {
                    inblock = 0
                    if (buf !~ ("<Name>" name "</Name>")) printf "%s", buf
                }
                next
            }
            /<\/Anims>/ { while ((getline line < blockfile) > 0) print line; print; next }
            { print }
        ' "$XML" >"$TMP/AnimData.xml" && mv "$TMP/AnimData.xml" "$XML"
    else
        { printf '<?xml version="1.0" encoding="utf-8"?>\n<AnimData>\n  <ShadowSize>1</ShadowSize>\n  <Anims>\n'
          cat "$block"
          printf '  </Anims>\n</AnimData>\n'
        } >"$XML"
    fi
    note "updated $XML (<Anim>$NAME</Anim>)"
fi

# --- 7. preview --------------------------------------------------------------
if (( PREVIEW )); then
    # keyed by pack too, so a fan-out run does not overwrite its own previews
    P="${TMPDIR:-/tmp}/mksheet-$(basename "$OUT")-${NAME}-preview.png"
    magick "$SHEET" -filter Point -resize 600% "$TMP/big.png"
    read -r pw ph <<<"$(magick identify -format '%w %h' "$TMP/big.png")"
    # over a checkerboard, so leftover background shows up instead of blending
    # into a white page
    magick -size "${pw}x${ph}" pattern:checkerboard -auto-level "$TMP/big.png" -composite "$P"
    printf '%s\n' "$P"
fi