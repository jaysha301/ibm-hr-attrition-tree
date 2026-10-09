"""Visuals for attrition_narrative_v3. Numbers ONLY from analysis/exec/exec_findings_draft.md:
16% left (line 6); 28% of staff, 54% of leavers (lines 6, 9); 31% vs 10% (line 9)."""
import os, sys
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
G = "/usr/share/fonts/truetype/sand-box/google/Carlito/"
for f in ("Carlito-Regular.ttf", "Carlito-Bold.ttf"): fm.fontManager.addfont(G + f)
plt.rcParams.update({"font.family": "Carlito", "font.size": 10})
ACC = "#C2410C"; BAR = "#C9C9C9"; TRACK = "#EFEFEF"; TXT = "#404040"; MUT = "#6B6B6B"; DARK = "#262626"

def save(fig, name):
    if os.path.exists(name) and "--force" not in sys.argv:
        sys.exit(f"{name} exists; refusing to overwrite")
    fig.savefig(name, dpi=300); plt.close(fig)

# (a) big-number strip
fig = plt.figure(figsize=(7.0, 1.25))
tiles = [
    ("16%", "of all employees left", DARK, None),
    ("28%", "of staff work overtime", ACC, None),
    ("31%", "of overtime workers left,\nvs 10% of staff without overtime", ACC, None),
    ("54%", "of everyone who left\nworked overtime", ACC, None),
]
xs = [0.0, 0.22, 0.46, 0.78]
for x, (big, lab, col, _) in zip(xs, tiles):
    fig.text(x + 0.005, 0.66, big, fontsize=30, fontweight="bold", color=col, ha="left", va="center")
    fig.text(x + 0.005, 0.36, lab, fontsize=9.5, color=TXT, ha="left", va="top", linespacing=1.15)
save(fig, "numbers_strip_v3.png")

# (b) chart: share of staff vs share of leavers, and leave rates
fig, axes = plt.subplots(1, 2, figsize=(7.0, 2.35), gridspec_kw={"width_ratios": [1, 1], "wspace": 0.3})
fig.subplots_adjust(left=0.0, right=0.97, top=0.62, bottom=0.04)
fig.text(0.0, 0.93, "Overtime workers are 28% of staff but 54% of everyone who left",
         fontsize=13, fontweight="bold", color=DARK, ha="left")
fig.text(0.0, 0.81, "IBM\u2019s fictional teaching data, 1,470 simulated employees", fontsize=9, color=MUT, ha="left")

ax = axes[0]
for y, (lab, v) in zip([1, 0], [("All staff", 28), ("Everyone who left", 54)]):
    ax.barh(y, 100, height=0.5, color=TRACK, zorder=1)
    ax.barh(y, v, height=0.5, color=ACC, zorder=2)
    ax.text(v + 2, y, f"{v}%", va="center", ha="left", fontsize=12, fontweight="bold", color=ACC)
    ax.text(0, y + 0.3, lab, va="bottom", ha="left", fontsize=9.5, color=TXT)
ax.set_xlim(0, 100); ax.set_ylim(-0.35, 1.6); ax.axis("off")
ax.text(0, 1.75, "Overtime workers\u2019 share of\u2026", fontsize=9.5, color=MUT, ha="left", va="bottom", fontweight="bold")

ax = axes[1]
for y, (lab, v, col) in zip([1, 0], [("Staff without overtime", 10, BAR), ("Overtime workers", 31, ACC)]):
    ax.barh(y, 100, height=0.5, color=TRACK, zorder=1)
    ax.barh(y, v, height=0.5, color=col, zorder=2)
    ax.text(v + 2, y, f"{v}%", va="center", ha="left", fontsize=12, fontweight="bold", color=(ACC if col == ACC else TXT))
    ax.text(0, y + 0.3, lab, va="bottom", ha="left", fontsize=9.5, color=(ACC if col == ACC else TXT),
            fontweight=("bold" if col == ACC else "normal"))
ax.set_xlim(0, 100); ax.set_ylim(-0.35, 1.6); ax.axis("off")
ax.text(0, 1.75, "Share who left", fontsize=9.5, color=MUT, ha="left", va="bottom", fontweight="bold")
save(fig, "overtime_chart_v3.png")
print("ok")
