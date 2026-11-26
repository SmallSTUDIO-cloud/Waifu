#!/usr/bin/env bash
# Capture one preview action as a still PNG + animated GIF, uploaded as
# check-run annotations. Usage: capture_preview.sh ACTION FRAMES FRAME_NUMBER
# Kept as a script so the workflow can split actions across several steps:
# GitHub processes at most 10 warning annotations per step (2 per action here).
set -euo pipefail
action="$1"; frames="$2"; frame_number="$3"
preview_action="$action"
extra=()
if [[ "$action" == authored-* ]]; then preview_action="${action#authored-}"; extra+=("--preview-authored"); fi
if [[ "$action" == baseline-review ]]; then preview_action="review-front"; extra+=("--legacy-walk" "--legacy-dash"); fi
if [[ "$action" == legacy-move ]]; then preview_action="move"; extra+=("--legacy-walk"); fi
if [[ "$action" == legacy-dodge ]]; then preview_action="dodge"; extra+=("--legacy-dash"); fi
mkdir -p "/tmp/preview-$action"
xvfb-run -a godot --path native3d --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --write-movie "/tmp/preview-$action/frame.png" --fixed-fps 30 --quit-after "$frames" -- "--preview-$preview_action" ${extra[@]+"${extra[@]}"} > "/tmp/preview-$action.log" 2>&1
if grep -E 'SCRIPT ERROR|^ERROR:' "/tmp/preview-$action.log"; then exit 1; fi
shot=$(find "/tmp/preview-$action" -name '*.png' | sort | sed -n "${frame_number}p")
test -n "$shot"
python3 -c 'import base64,json,sys; print(json.dumps({"content":base64.b64encode(open(sys.argv[1],"rb").read()).decode(),"encoding":"base64"}))' "$shot" > /tmp/preview-blob.json
sha=$(gh api "repos/$GITHUB_REPOSITORY/git/blobs" --method POST --input /tmp/preview-blob.json --jq .sha)
echo "::warning title=Preview $action::$sha"
python3 - "$action" <<'PYCODE'
import glob, sys
from PIL import Image
action = sys.argv[1]
paths = sorted(glob.glob('/tmp/preview-' + action + '/*.png'))
frames = []
for path in paths[::2]:
    im = Image.open(path).convert('RGB')
    im.thumbnail((640, 360))
    frames.append(im.quantize(colors=128, method=Image.Quantize.FASTOCTREE))
frames[0].save('/tmp/preview-' + action + '.gif', save_all=True, append_images=frames[1:], duration=67, loop=0, optimize=True)
PYCODE
python3 -c 'import base64,json,sys; print(json.dumps({"content":base64.b64encode(open(sys.argv[1],"rb").read()).decode(),"encoding":"base64"}))' "/tmp/preview-$action.gif" > /tmp/preview-gif.json
gifsha=$(gh api "repos/$GITHUB_REPOSITORY/git/blobs" --method POST --input /tmp/preview-gif.json --jq .sha)
echo "::warning title=Animation $action::$gifsha"
echo "$action gif=$gifsha still=$sha" >> /tmp/preview-manifest.txt
