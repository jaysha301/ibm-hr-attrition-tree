"""Chart for attrition_narrative_v8. Numbers ONLY from analysis/exec2/exec_findings_v2_draft.md:
16% company rate, 10% without overtime, 416 / 31% overtime, 54% of leavers (lines 6, 9);
lower-paid junior overtime workers about 115-130 people, about 55%, close to 30% of leavers (line 11)."""
import os, sys
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
G = "/usr/share/fonts/truetype/sand-box/google/Carlito/"
for f in ("Carlito-Regular.ttf", "Carlito-Bold.ttf"): fm.fontManager.addfont(G + f)
plt.rcParams.update({"font.family": "Carlito", "font.size": 10})
ACC = "#C2410C"; ACC2 = "#7C2D12"; BAR = "#C9C9C9"; TRACK = "#EFEFEF"; TXT = "#404040"; MUT = "#6B6B6B"; DARK = "#262626"

def save(fig, name):
    if os.path.exists(name) and "--force" not in sys.argv:
        sys.exit(f"{name} exists; refusing to overwrite")
    fig.savefig(name, dpi=300); plt.close(fig)

fig = plt.figure(figsize=(7.0, 3.2))
fig.text(0.0, 0.96, "Overtime workers leave most, and lower-paid junior overtime workers most of all",
         fontsize=13, fontweight="bold", color=DARK, ha="left", va="center")
fig.text(0.0, 0.89, "IBM\u2019s fictional teaching data, 1,470 simulated employees", fontsize=9, color=MUT,
         ha="left", va="center")

# Panel 1: share who left
ax = fig.add_axes([0.0, 0.13, 0.60, 0.62])
rows = [("All staff", "1,470 people", 16, BAR, TXT, "16%"),
        ("Staff without overtime", "", 10, BAR, TXT, "10%"),
        ("Overtime workers", "416 people", 31, ACC, ACC, "31%"),
        ("Lower-paid, junior overtime workers", "about 115 to 130 people", 55, ACC2, ACC2, "about 55%")]
ys = [3, 2, 1, 0]
for y, (lab, n, v, col, tcol, vt) in zip(ys, rows):
    ax.barh(y, 100, height=0.42, color=TRACK, zorder=1)
    ax.barh(y, v, height=0.42, color=col, zorder=2)
    ax.text(v + 1.5, y, vt, va="center", ha="left", fontsize=11, fontweight="bold", color=tcol)
    bold = col != BAR
    ax.text(0, y + 0.27, lab, va="bottom", ha="left", fontsize=9.5, color=tcol, fontweight=("bold" if bold else "normal"))
    if n:
        ax.text(100, y + 0.27, n, va="bottom", ha="right", fontsize=8.5, color=MUT)
ax.set_xlim(0, 100); ax.set_ylim(-0.4, 3.75); ax.axis("off")
ax.text(0, 3.95, "Share who left", fontsize=9.5, color=MUT, fontweight="bold", ha="left", va="bottom")

# Panel 2: share of all leavers (nested)
ax = fig.add_axes([0.68, 0.13, 0.32, 0.62])
ax.barh(1, 100, height=0.42, color=TRACK, zorder=1)
ax.barh(1, 54, height=0.42, color=ACC, zorder=2)
ax.barh(1, 30, height=0.42, color=ACC2, zorder=3)
ax.text(54 + 2, 1, "54%", va="center", ha="left", fontsize=11, fontweight="bold", color=ACC)
ax.text(0, 1 + 0.27, "Overtime workers", va="bottom", ha="left", fontsize=9.5, color=ACC, fontweight="bold")
ax.plot([15, 15], [1 - 0.21, 0.45], color=ACC2, lw=0.8)
ax.text(0, 0.12, "of which lower-paid, junior:", va="bottom", ha="left", fontsize=9.5, color=ACC2)
ax.text(0, 0.12, "close to 30%", va="top", ha="left", fontsize=11, fontweight="bold", color=ACC2)
ax.set_xlim(0, 100); ax.set_ylim(-0.4, 3.75); ax.axis("off")
ax.text(0, 3.95, "Share of everyone who left", fontsize=9.5, color=MUT, fontweight="bold", ha="left", va="bottom")

fig.text(0.0, 0.04, "Lower-paid, junior overtime workers earn under roughly \\$3,000 to \\$3,500 a month and are part of the overtime group.",
         fontsize=8.5, color=MUT, ha="left", va="center")
save(fig, "leaving_chart_v9.png")
print("ok")
