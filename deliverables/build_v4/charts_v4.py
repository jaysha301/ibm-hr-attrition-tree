"""Visuals for attrition_narrative_v4. Numbers ONLY from analysis/exec/exec_findings_draft.md:
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

# (a) big-number strip (v4: rates only; the chart carries the 28% / 54% shares, so nothing repeats)
fig = plt.figure(figsize=(7.0, 1.05))
tiles = [
    ("16%", "of all employees left", DARK),
    ("31%", "of overtime workers left", ACC),
    ("10%", "of staff without overtime left", MUT),
]
xs = [0.0, 0.30, 0.60]
for x, (big, lab, col) in zip(xs, tiles):
    fig.text(x + 0.005, 0.66, big, fontsize=30, fontweight="bold", color=col, ha="left", va="center")
    fig.text(x + 0.005, 0.24, lab, fontsize=10, color=(ACC if col == ACC else TXT), ha="left", va="center")
save(fig, "numbers_strip_v4.png")

# (b) chart: overtime workers' share of staff vs share of leavers (single panel)
fig, ax = plt.subplots(figsize=(7.0, 1.95))
fig.subplots_adjust(left=0.0, right=0.62, top=0.66, bottom=0.04)
fig.text(0.0, 0.92, "Overtime workers are 28% of staff but 54% of everyone who left",
         fontsize=13, fontweight="bold", color=DARK, ha="left")
fig.text(0.0, 0.79, "IBM\u2019s fictional teaching data, 1,470 simulated employees", fontsize=9, color=MUT, ha="left")
for y, (lab, v) in zip([1, 0], [("Overtime workers\u2019 share of all staff", 28),
                                ("Overtime workers\u2019 share of everyone who left", 54)]):
    ax.barh(y, 100, height=0.5, color=TRACK, zorder=1)
    ax.barh(y, v, height=0.5, color=ACC, zorder=2)
    ax.text(v + 2, y, f"{v}%", va="center", ha="left", fontsize=12, fontweight="bold", color=ACC)
    ax.text(0, y + 0.3, lab, va="bottom", ha="left", fontsize=9.5, color=TXT)
ax.set_xlim(0, 100); ax.set_ylim(-0.35, 1.6); ax.axis("off")
save(fig, "overtime_chart_v4.png")
print("ok")
