"""Builds attrition_narrative_v1.docx. Numbers: analysis/findings_draft.md v0.3 only.
Research: research/interpretation.md (QA-cleared 3:43 PM PT version) and research/attrition_drivers.md
(author, year as given there). JobLevel-1 figure as written in interpretation.md line 25 (also findings_draft.md line 47)."""
import os, sys
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn

OUT = "../attrition_narrative_v2.docx"
if os.path.exists(OUT) and "--force" not in sys.argv:
    sys.exit(f"{OUT} exists; refusing to overwrite")

BODY, FONT = Pt(10), "Calibri"
DARK, MID, LIGHT, ACCENT = RGBColor(0x26,0x26,0x26), RGBColor(0x40,0x40,0x40), RGBColor(0x80,0x80,0x80), RGBColor(0xC0,0x50,0x4D)

doc = Document()
sec = doc.sections[0]
sec.page_width, sec.page_height = Inches(8.5), Inches(11)
sec.left_margin = sec.right_margin = Inches(0.9)
sec.top_margin, sec.bottom_margin = Inches(0.6), Inches(0.6)

st = doc.styles["Normal"]
st.font.name = FONT; st.font.size = BODY; st.font.color.rgb = MID
st.element.rPr.rFonts.set(qn("w:eastAsia"), FONT)
st.paragraph_format.space_after = Pt(5)
st.paragraph_format.line_spacing = 1.08

def para(parts, size=None, color=None, after=None, before=None, align=None):
    p = doc.add_paragraph()
    if isinstance(parts, str): parts = [(parts, "")]
    for text, fmt in parts:
        r = p.add_run(text)
        r.bold = "b" in fmt; r.italic = "i" in fmt
        if size: r.font.size = size
        if color is not None: r.font.color.rgb = color
        if "a" in fmt: r.font.color.rgb = ACCENT
        if "d" in fmt: r.font.color.rgb = DARK
    pf = p.paragraph_format
    if after is not None: pf.space_after = Pt(after)
    if before is not None: pf.space_before = Pt(before)
    p.alignment = align or WD_ALIGN_PARAGRAPH.LEFT
    return p

def heading(text):
    p = para([(text, "b")], size=Pt(12.5), color=DARK, before=10, after=4)
    p.paragraph_format.keep_with_next = True

para([("Where overtime meets entry-level pay: an attrition story from IBM\u2019s fictional HR teaching dataset", "b")],
     size=Pt(18), color=DARK, after=4)
para("A narrative summary for HR and business leaders. Every figure describes simulated employees in a dataset "
     "IBM created for teaching (1,470 in all; most rates use the 441 held back for testing), not real people and "
     "not any real employer.",
     size=Pt(10.5), color=LIGHT, after=6)

heading("What we looked at: 1,470 simulated employees in IBM\u2019s fictional dataset")
para("IBM built this dataset so people could practice HR analytics. It describes 1,470 simulated employees, "
     "237 of whom left (16.1%). None of them are real, and the patterns say nothing about IBM\u2019s own workforce "
     "or any other organization; it is a place to practice reading attrition data.")
para("The question was simple: which characteristics best separate the people who left from those who stayed? "
     "The analysis grew a classification tree, which keeps splitting employees into groups with higher and lower "
     "attrition, on most of the records, then checked it on the 441 records it had never seen (the held-out test set). Monthly income was the only pay measure; three rate fields in the file (DailyRate, "
     "HourlyRate and MonthlyRate) were left out because they cannot be read as pay. Only the tree\u2019s first two "
     "splits were supported by cross-validation (in 18 of 20 reruns), so those two splits are the whole story told here.")

heading("The pattern in the fictional data: overtime, and above all overtime at entry-level pay")
para("The first and clearest dividing line was overtime. In the test set, 32.5% of overtime workers left "
     "(37 of 114; 95% CI 24.6\u201341.5%), compared with 10.4% of everyone else (34 of 327; CI 7.5\u201314.2%). "
     "That is about 3 times as high.")
para("Within the overtime group, pay sharpened the picture. Overtime workers paid under about $2,500 a month, "
     "roughly the lowest 15% of earners, left at 63.2% (12 of 19; CI 41.0\u201380.9%), compared with 26.3% of "
     "better-paid overtime workers (25 of 95; CI 18.5\u201336.0%). Without overtime, the income gap was smaller: "
     "17.9% (7 of 39; CI 9.0\u201332.7%) versus 9.4% (27 of 288; CI 6.5\u201313.3%).")
p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(4); p.paragraph_format.space_after = Pt(6)
p.add_run().add_picture("chart_attrition_fictional.png", width=Inches(5.7))
p.paragraph_format.keep_with_next = False

para("Two cautions. First, the $2,500 line is approximate. The tree split at $2,475, but when "
     "the analysis was refit on resampled data, about 37% of the cuts landed above $2,700. Second, the low-paid "
     "group is almost entirely entry-level: of the 220 employees under $2,475 in the full dataset, 210 are at JobLevel 1. Low pay, "
     "junior level, few years of experience and short tenure travel together in this data, so the accurate label "
     "is \u201clowest-paid, mostly entry-level employees.\u201d Low income largely overlaps with early career but is not "
     "quite the same thing: within JobLevel 1, those paid under $2,475 still left at 35.7% (75 of 210), against "
     "20.4% (68 of 333) of better-paid JobLevel 1 employees (full data). Even so, the analysis cannot say whether pay, career stage or "
     "something else is doing the work.")
para("These are associations, not causes; overtime, for example, may simply mark understaffed or junior roles. "
     "The tree is also a coarse description rather than a forecasting tool. Its test AUC was 0.670, while a "
     "logistic regression on the same data, which picks up many small effects that add up, reached 0.863. At "
     "the threshold used, the tree flagged only 33.8% of test-set leavers (24 of 71). It describes some of what distinguishes "
     "leavers; it cannot pick out individuals. Two deeper patterns, one involving marital status (every single "
     "employee here has no stock options, though many married or divorced employees have none either) and one "
     "involving job role, are leads to check, not "
     "findings: they rest on small groups and were not supported by cross-validation.")

heading("Why these patterns would matter in real organizations, illustrated by fictional data")
para("Fictional data cannot confirm research or speak for any real employer, but published studies help explain why such patterns would matter. The "
     "overtime gap is, if anything, larger than research would lead us to expect. In one widely used framework, workload "
     "counts as a challenge stressor, a demand linked to lower rather than higher turnover (Podsakoff et al., 2007), "
     "and on its own it is only weakly related to leaving (Rubenstein et al., 2018). When fictional data and the "
     "literature disagree like this, the likely explanation is how the simulated data were generated, not a new "
     "finding. Still, the kind of overtime may matter: long hours can take time and "
     "energy from family and other roles (Greenhaus & Beutell, 1985), and whether overtime feels like a burden "
     "has to be asked, not assumed.")
para("The combination of overtime and low pay fits two classic ideas, as an illustration rather than a tested "
     "mechanism. People stay while what they get from an organization outweighs what they give (March & Simon, "
     "1958), and people who feel under-rewarded for their effort are motivated to restore the balance, sometimes "
     "by leaving (Adams, 1965). Overtime adds to what the employee gives; low pay lowers what they get. Pay "
     "itself is a real but modest predictor of turnover, and \u201cmany other predictors more readily controlled by "
     "managers can be more important than pay\u201d (Rubenstein et al., 2018). The early-career reading fits "
     "research too: newer employees have built up fewer stakes and ties that hold them in place (Becker, 1960; "
     "Mitchell et al., 2001), and shorter-tenured employees quit more often (Rubenstein et al., 2018).")

heading("What it suggests: four suggestions from fictional data and research, not tested interventions")
para("For a real organization seeing similar patterns, the findings and research point to four places to look; "
     "these are suggestions, not tested interventions.")
para([("Review overtime load and who carries it. ", "bd"),
      ("Look at whether overtime is concentrated among lower-paid, early-career staff, whether people choose "
       "it, and whether it is sustained. Treat it as a workload question, and ask employees whether it feels "
       "like a stretch or a burden rather than assuming either.", "")])
para([("Look at pay and early-career progression together. ", "bd"),
      ("Because low pay and junior level are entangled, pair a pay audit for lower-paid employees who work "
       "overtime, including how raises are allocated, with visible next steps in development and promotion. Research links felt inequity to exit (Adams, "
       "1965), low salary growth to exits (Trevor et al., 1997), and stalled careers to lower attachment, "
       "mostly measured as intentions to leave (Yang et al., 2019).", "")])
para([("Ask people why they stay, across whole groups. ", "bd"),
      ("Stay interviews offered to everyone in a group, for example all overtime workers, can surface the "
       "ties, fit and stakes that research links to staying (Mitchell et al., 2001); reasons for staying differ "
       "by job type and performance level (Hausknecht et al., 2009).", "")])
para([("Use stronger, properly validated models, and real data, before any individual-level use. ", "bd"),
      ("This tree is a useful sketch, not a scoring tool. Any real-world model should be built on the "
       "organization\u2019s own data, validated on new data, checked for fairness, and treated as one input among many. "
       "Real HR files also usually lack what research rates as the strongest signals, intentions to leave and "
       "job search (Rubenstein et al., 2018), and rarely record employees\u2019 outside job options.", "")])
para("One guardrail: age, gender and marital status are descriptions only, and nothing here should be used to "
     "target or make decisions about people by them. "
     "On age and marital status, Rubenstein et al. (2018) write that \u201cdue to equal employment opportunity concerns, we cannot advise "
     "organizations to select individuals based on their age, marital status, or how many children they have.\u201d "
     "Gender is descriptive only by this team\u2019s own rule.")
para("In short: in this simulated workforce, leaving clustered where overtime met entry-level pay. That is a reason "
     "to ask careful questions of real data, not an answer in itself.")

refs = [
 "Adams (1965), Advances in Experimental Social Psychology.",
 "Becker (1960), American Journal of Sociology.",
 "Greenhaus & Beutell (1985), Academy of Management Review.",
 "Hausknecht, Rodda & Howard (2009), Human Resource Management.",
 "March & Simon (1958), Organizations, Wiley.",
 "Mitchell, Holtom, Lee, Sablynski & Erez (2001), Academy of Management Journal.",
 "Podsakoff, LePine & LePine (2007), Journal of Applied Psychology.",
 "Rubenstein, Eberly, Lee & Mitchell (2018), Personnel Psychology.",
 "Trevor, Gerhart & Boudreau (1997), Journal of Applied Psychology.",
 "Yang, Niven & Johnson (2019), Journal of Vocational Behavior.",
]
para([("About the numbers and sources (fictional data). ", "b"),
      ("Figures come from the project\u2019s QA-approved findings (v0.3) and are held-out test-set rates unless "
       "noted (the JobLevel 1 comparison is full data); CIs are Wilson 95% intervals. Research comes from the "
       "team\u2019s QA-reviewed literature brief and interpretation; it describes real organizations, and the "
       "links here are illustrative only. References (full citations in research/attrition_drivers.md): " + "; ".join(r.split("),")[0] + ")" for r in refs) + ".", "")],
     size=Pt(8), color=LIGHT, before=4, after=0)

doc.save(OUT)
print("saved", OUT)
