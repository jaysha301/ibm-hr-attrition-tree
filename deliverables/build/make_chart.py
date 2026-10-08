"""Chart for attrition_narrative_v1. All numbers from analysis/findings_draft.md (v0.3):
line 26 (no overtime, test: 10.4%, 34/327, CI 7.5-14.2%) and
line 31 (overtime + under about $2,500: 63.2%, 12/19, CI 41.0-80.9%;
         overtime + about $2,500 or more: 26.3%, 25/95, CI 18.5-36.0%)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.transforms
from matplotlib import font_manager as fm

FONT = "Carlito"  # metric-compatible with Calibri, the docx body font
plt.rcParams["font.family"] = FONT
GRAY, DARK, ACCENT, LIGHT = "#BFBFBF", "#595959", "#C0504D", "#8C8C8C"

rows = [  # label, sublabel, rate, lo, hi, n-text, accent
    ("No overtime", "34 of 327 left", 10.4, 7.5, 14.2, False),
    ("Overtime, paid about $2,500/month or more", "25 of 95 left", 26.3, 18.5, 36.0, False),
    ("Overtime, paid under about $2,500/month", "12 of 19 left", 63.2, 41.0, 80.9, True),
]

fig, ax = plt.subplots(figsize=(6.5, 2.45), dpi=300)
fig.subplots_adjust(left=0.44, right=0.97, top=0.70, bottom=0.03)
ys = [2, 1, 0]
for y, (lab, sub, r, lo, hi, acc) in zip(ys, rows):
    col = ACCENT if acc else GRAY
    ax.barh(y, r, height=0.58, color=col, zorder=2)
    ax.plot([lo, hi], [y, y], color=("#7A2E2B" if acc else LIGHT), lw=0.9, zorder=3, solid_capstyle="butt")
    for x in (lo, hi):
        ax.plot([x, x], [y - 0.09, y + 0.09], color=("#7A2E2B" if acc else LIGHT), lw=0.9, zorder=3)
    ax.text(hi + 1.5, y, f"{r:.1f}%", va="center", ha="left", fontsize=10.5,
            fontweight="bold", color=(ACCENT if acc else DARK))
    tr = matplotlib.transforms.blended_transform_factory(fig.transFigure, ax.transData)
    ax.text(0.02, y + 0.11, lab, va="center", ha="left", fontsize=9, transform=tr,
            color=(ACCENT if acc else DARK), fontweight=("bold" if acc else "normal"))
    ax.text(0.02, y - 0.2, sub, va="center", ha="left", fontsize=8, color=LIGHT, transform=tr)

ax.set_xlim(0, 90); ax.set_ylim(-0.5, 2.5)
ax.axis("off")
fig.text(0.02, 0.92, "In fictional data, overtime workers paid under about $2,500 a month left most often",
         fontsize=11.5, fontweight="bold", color="#262626", ha="left")
fig.text(0.02, 0.84, "Share of simulated employees who left, held-out test set (441 of IBM's 1,470 fictional employees).\n"
         "Thin lines show 95% confidence intervals; the smallest group has only 19 people.",
         fontsize=8.3, color=LIGHT, ha="left", va="top", linespacing=1.3)
fig.savefig("chart_attrition_fictional.png", dpi=300)
print("ok")
