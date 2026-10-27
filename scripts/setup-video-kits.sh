#!/usr/bin/env bash
# Rebuild the video-editing toolchain in a fresh Claude Code cloud container.
#
# The HyperFrames core skills and ffmpeg-skill are committed under
# .claude/skills and need nothing from this script except Chrome (step 1).
# Herk Edit Kit and claude-code-video-toolkit are workspaces: you open Claude
# Code inside them, so they are cloned outside this repo.
#
# Free and local only. Nothing here signs up for or calls a paid service.
set -euo pipefail

KITS_DIR="${VIDEO_KITS_DIR:-/home/user/video-kits}"
HERK_REV=10511e5af86fc47756ea89803b397422e2d89284
TOOLKIT_REV=da3f474c1230d161be1384ef97aec27f73b11636
HYPERFRAMES_VERSION=0.8.207

clone_at() { # url dir rev
  if [ ! -d "$2/.git" ]; then
    git clone --quiet "$1" "$2"
  fi
  git -C "$2" fetch --quiet origin "$3" 2>/dev/null || true
  git -C "$2" checkout --quiet "$3"
}

# 1. Chrome headless shell for HyperFrames renders (and for Remotion, below).
npx -y "hyperframes@${HYPERFRAMES_VERSION}" browser ensure

# 2. FFmpeg 7 for Herk Edit Kit only. Its cut scripts pass `-/filter_complex`,
#    which FFmpeg 6.1 (the system build) does not understand. This static
#    build lacks drawtext, which ffmpeg-skill needs, so it stays off the
#    global PATH and only the Herk workspace sees it.
if [ ! -x /opt/ffmpeg7/bin/ffmpeg ]; then
  tmp="$(mktemp -d)"
  pip download --quiet --no-deps --only-binary=:all: \
    --platform manylinux2014_x86_64 imageio-ffmpeg==0.6.0 -d "$tmp"
  python3 -m zipfile -e "$tmp"/imageio_ffmpeg-*.whl "$tmp/x"
  mkdir -p /opt/ffmpeg7/bin
  install -m 755 "$tmp"/x/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.* /opt/ffmpeg7/bin/ffmpeg
  ln -sf "$(command -v ffprobe)" /opt/ffmpeg7/bin/ffprobe
  rm -rf "$tmp"
fi

mkdir -p "$KITS_DIR"

# 3. Herk Edit Kit (https://github.com/nateherkai/herk-edit-kit)
HERK="$KITS_DIR/herk-edit-kit"
clone_at https://github.com/nateherkai/herk-edit-kit.git "$HERK" "$HERK_REV"
(cd "$HERK" && npm ci --silent && npm run --silent setup && npm test --silent)
cat > "$HERK/.claude/settings.local.json" <<EOF
{
  "env": { "PATH": "/opt/ffmpeg7/bin:$PATH" }
}
EOF

# 4. claude-code-video-toolkit (https://github.com/digitalsamba/claude-code-video-toolkit)
TOOLKIT="$KITS_DIR/claude-code-video-toolkit"
clone_at https://github.com/digitalsamba/claude-code-video-toolkit.git "$TOOLKIT" "$TOOLKIT_REV"
(cd "$TOOLKIT" && uv sync --quiet)
(cd "$TOOLKIT/examples/hello-world" && npm install --silent)

echo "Video kits ready in $KITS_DIR."
echo "Remotion cannot download its own Chrome here; render with:"
echo "  npx remotion render ... --browser-executable=\"\$(ls /opt/pw-browsers/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell | head -1)\""
