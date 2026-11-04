"""Build the README's app tour: the iPhone app's main screens, one caption per screen.

The phone sits on the right, the caption on the left. Every frame is a real simulator screen recording of the
current app (iOS 26 simulator; the glasses are simulated with MockDeviceKit playing a licensed CC BY video):

- results/walkthrough/demo_story_raw.mp4: --autorun-e2e, PR_AUTORUN_RECORD_S=78 (record -> Meta AI builds ->
  draft -> publish -> feed)
- results/walkthrough/tour/{story,library,lens}.mp4: --open-story=<id>, --tab=library,
  --open-guide=<id> --autorun-lens, recorded with `xcrun simctl io <device> recordVideo`

    uv run --with pillow python scripts/make_app_tour.py
    -> results/walkthrough/app_tour.mp4 (kept out of git; the README links the uploaded copy)
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
WALK = ROOT / "results/walkthrough"
OUT = WALK / "app_tour.mp4"

W, H, FPS = 1280, 720, 30
BG = (245, 245, 242)
INK = (27, 27, 31)
MUTE = (107, 107, 116)
ACCENT = (47, 91, 211)
FONT = "/System/Library/Fonts/HelveticaNeue.ttc"

# (recording, start s, end s, speed-up, kicker, headline, sub)
SCENES = [
    ("demo_story_raw.mp4", 18.5, 97.5, 20, "RECORD", "Work and talk.",
     "The glasses' view, a live caption of what you say,\nand Mark step. Stop when the job is done."),
    ("demo_story_raw.mp4", 99.5, 212.8, 30, "META AI BUILDS THE GUIDE", "One Muse Spark call.",
     "It watches the video, reads the transcript and\non-screen text, and writes the steps."),
    ("demo_story_raw.mp4", 213.4, 216.2, 1.0, "DRAFT", "Check the steps.",
     "Edit a step's words or re-cut its start and end."),
    ("demo_story_raw.mp4", 216.6, 219.8, 1.0, "PUBLISH", "Title and category, suggested.",
     "Public guides go to the Feed. Private ones stay yours."),
    ("demo_story_raw.mp4", 220.0, 224.8, 1.5, "FEED", "Guides by category.",
     "Like and save. Tap a card to open it."),
    ("tour/story.mp4", 10.0, 24.0, 1.0, "STORY", "A summary, then one clip per step.",
     "Each step loops with its instruction, a done-when\ncheck and the instructor's words."),
    ("tour/lens.mp4", 15.0, 33.0, 1.5, "LENS MODE", "The step on the glasses' display.",
     "Back, Next, Replay on the lens, or say \"next\".\n(Display glasses simulated.)"),
    ("tour/library.mp4", 5.0, 9.0, 1.0, "LIBRARY", "Pick up where you stopped.",
     "Saved guides, your own guides, and who can see them."),
]

PH = 640
PW = round(1206 / 2622 * PH)
PX, PY = W - PW - 110, (H - PH) // 2


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def duration(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         check=True, capture_output=True, text=True).stdout
    return float(out)


def card(path: Path, i: int, kicker: str, head: str, sub: str) -> None:
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    x = 96
    d.text((x, 250), f"{i + 1} / {len(SCENES)}   {kicker}", font=font(18, True), fill=ACCENT)
    d.text((x, 284), head, font=font(42, True), fill=INK)
    d.multiline_text((x, 350), sub, font=font(22), fill=MUTE, spacing=8)
    d.text((x, H - 60), "Firsthand  ·  iOS simulator, glasses simulated", font=font(15), fill=MUTE)
    img.save(path)


def mask(path: Path) -> None:
    img = Image.new("L", (PW, PH), 0)
    ImageDraw.Draw(img).rounded_rectangle((0, 0, PW - 1, PH - 1), radius=38, fill=255)
    img.save(path)


def main() -> None:
    tmp = Path(tempfile.mkdtemp(prefix="tour_"))
    mask(tmp / "mask.png")
    parts = []
    for i, (src, a, b, speed, kicker, head, sub) in enumerate(SCENES):
        video = WALK / src
        a = 0.0 if a is None else a
        b = duration(video) if b is None else b
        card(tmp / f"card{i}.png", i, kicker, head, sub)
        part = tmp / f"part{i}.mp4"
        run(["ffmpeg", "-v", "error", "-y", "-ss", str(a), "-t", str(b - a), "-i", str(video),
             "-loop", "1", "-i", str(tmp / f"card{i}.png"), "-i", str(tmp / "mask.png"),
             "-filter_complex",
             f"[0:v]setpts=PTS/{speed},fps={FPS},scale={PW}:{PH}[p];[p][2:v]alphamerge[pm];"
             f"[1:v][pm]overlay={PX}:{PY}:shortest=1,format=yuv420p[v]",
             "-map", "[v]", "-an", "-c:v", "libx264", "-crf", "23", "-preset", "medium", str(part)])
        parts.append(part)
    (tmp / "list.txt").write_text("".join(f"file '{p}'\n" for p in parts))
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(tmp / "list.txt"),
         "-c:v", "libx264", "-crf", "23", "-movflags", "+faststart", str(OUT)])
    print(f"wrote {OUT} ({duration(OUT):.1f} s)")


if __name__ == "__main__":
    main()
