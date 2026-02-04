# CGIC Dashboard V2 Updates - Change Summary

## Overview
This update addresses all feedback items from `Mock_Dashboard_Feedback_V2.docx` (except data-related changes which were out of scope).

---

## Changes Made

### 1. ✅ Global Sidebar Filters
**What:** Filters now appear on ALL tabs (Overview, Map & Incidents, Clearance, NIBIN & Sankey)
**Why:** Users no longer need to switch back to Overview to change or see filter settings
**How:** Restructured UI to use `sidebarLayout()` wrapping each tab's content

### 2. ✅ Clear Filters Button
**What:** Added "Clear Filters" button at bottom of sidebar
**Why:** Allows users to reset all filters to defaults without manually adjusting each one
**Resets:** Date range, incident type, beat, hits only checkbox, min incidents slider, gun selection

### 3. ✅ Renamed "Event Type" → "Incident Type"
**What:** Filter label changed from "Event type" to "Incident type"
**Where:** Sidebar filter, map legend
**Note:** Internal data column still uses `event_type` for compatibility

### 4. ✅ Updated Footer Disclaimer
**What:** New grant number and language per BJA requirements
**New text:** 
> "This project is funded through a grant from the Bureau of Justice Assistance, Office of Justice Programs, U.S. Department of Justice. Neither the U.S. Department of Justice nor any of its components operate, control, are responsible for, or necessarily endorse, this Web site (including, without limitation, its content, technical infrastructure, and policies, and any services or tools provided). This project was supported by Grant No. 15PBJA-24-GK-04259-BSCI awarded by the Bureau of Justice Assistance."

### 5. ✅ Updated Instructions Tab
- **Bullet 2:** Updated to reflect checkbox controls (was referencing old radio buttons)
- **Clear Filters:** Moved to its own bullet point
- **User Guide:** Added placeholder link for future User Guide document

### 6. ✅ Modal Disclaimer Matches Header
**What:** Welcome modal warning text now matches the header banner exactly
**Text:** "The data shown in this mock dashboard is manufactured and not representative of any actual city, locality, or jurisdiction."

### 7. ✅ NIBIN Tab: Minimum Incidents Filter
**What:** Added slider control "Minimum incidents per gun" (1-10, default 2)
**Why:** Allows executives to focus on guns with multiple incidents (e.g., 3+ linked incidents)
**Effect:** Filters Sankey diagram and related charts to show only guns meeting threshold

### 8. ✅ Gun Selector Searchability
**What:** Explicitly configured selectizeInput with search options
**How:** Added `searchField` and `searchConjunction` options

---

## NOT Changed (Out of Scope per Instructions)

| Feedback Item | Reason |
|--------------|--------|
| Add Guns Recovered/Seized from traffic stops | Requires new data/event types |
| Add POC field (name/rank) to tables | Requires new data columns |
| Fix Justified/Accidental event types | Data issue - categories may not exist in dataset |

---

## Files

- **app_updated.R** — Complete updated dashboard (2,257 lines)
- **CHANGELOG_V2_UPDATES.md** — This summary document

---

## Testing Checklist

After deploying, verify:

- [ ] Sidebar filters appear on Overview, Map, Clearance, and NIBIN tabs
- [ ] "Clear Filters" button resets all filters
- [ ] Filter label says "Incident type" not "Event type"
- [ ] Footer shows new grant number (15PBJA-24-GK-04259-BSCI)
- [ ] Instructions tab shows updated bullet points
- [ ] Welcome modal disclaimer matches header warning
- [ ] NIBIN tab has "Minimum incidents per gun" slider
- [ ] Slider filters Sankey diagram appropriately
- [ ] Gun selector dropdown is searchable
- [ ] All existing functionality still works

---

## Logo Update

**Note:** You mentioned a new cropped logo is coming from BJA. When you receive it:
1. Replace `www/cgic-logo-reverse.png` with the new file
2. Keep the same filename, or update the `brand_logo` section (around line 310)

---

## User Guide Link

Currently links to `#` (placeholder). When the User Guide is ready:
1. Find this line in the Instructions content (around line 348):
   ```r
   href = "#",
   ```
2. Replace `#` with the actual URL

---

## Deployment

1. Replace your existing `app.R` with `app_updated.R`
2. Rename to `app.R`
3. Ensure `data/poc/` folder and `www/` folder are in place
4. Run with `shiny::runApp()`
