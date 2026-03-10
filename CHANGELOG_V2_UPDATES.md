# CGIC Dashboard — Change Summary

## V3 Updates (March 2026)

This update addresses BJA and internal review feedback on terminology, usability, filtering, and layout.

---

### UI Architecture

#### Migrated to `page_navbar` with Single Global Sidebar
**What:** Replaced duplicated `sidebarLayout(global_sidebar, ...)` on each tab with bslib's `page_navbar(sidebar = ...)` architecture
**Why:** The old approach created duplicate input IDs in the DOM, causing filters to not visually sync across tabs and checkbox inputs to not work reliably
**Result:** All filters now exist as a single instance — no sync issues, Clear Filters works correctly on every tab

#### Smart Sidebar Auto-Toggle
**What:** Sidebar automatically closes on the Instructions tab and opens on all data tabs (Overview, Map, Clearance, NIBIN & Sankey)
**Why:** Instructions page doesn't need filters and benefits from full-width layout; data tabs need filters immediately visible
**How:** Server-side `observeEvent` on `input$main_nav` with `sidebar_toggle()`

#### Incident Type Filter Changed to Checkboxes
**What:** Replaced `selectizeInput` with `checkboxGroupInput` for incident type filtering
**Why:** Old approach required users to click items and hit delete to filter — unintuitive. Checkboxes are immediately obvious: uncheck to exclude
**Default:** All incident types checked

---

### Terminology & Language

#### Removed "Confirmed Hits" Language
**What:** Replaced "Confirmed Hits" with "Leads" or "Hits" per BJA best practices
**Where:**
- NIBIN & Sankey page: "Gun ↔ Incident Linkages" (was "...Confirmed Hits")
- NIBIN & Sankey page: "Top Gun ↔ Incident Links" (was "...links (Confirmed Hits; Simplified)")
- NIBIN & Sankey page: helper text updated to "NIBIN leads" language
- Overview page: chart title "NIBIN Leads & Hits" (was "...& Confirmed Hits")
- Overview page: helper text "Hits = links vetted by personnel" (was "confirmed links")
- Sidebar: checkbox label "NIBIN leads only" (was "Hits only (confirmed)")

#### "Event Type" → "Incident Type" in Tables
**What:** Added `colnames` to DT tables so column headers display "Incident Type" instead of raw `event_type`
**Where:** Incidents table (Map page), Links table (NIBIN page)

#### Capitalized "Links" in Table Title
**What:** "Top Gun ↔ Incident links" → "Top Gun ↔ Incident Links" for consistency

---

### Colors & Visualization

#### Accidental & Justified Shooting Colors
**What:** Added distinct colors for Accidental (green) and Justified (navy) incident types
**Where:**
- `pal` colorFactor for map markers (was defaulting to grey for both)
- `event_colors` in the Overview trend chart (lines were invisible before)
- Default filter selection (both types now included by default)

---

### Map Enhancements

#### Beat Boundary Overlay
**What:** Added "Show beats" checkbox on Map page that draws approximate beat boundaries
**How:** Voronoi tessellation from beat centroids (same technique as existing sector overlay), drawn with blue dashed lines and labels
**Note:** Uses approximate boundaries computed from incident locations since no official beat boundary files exist

---

### NIBIN & Sankey Enhancements

#### Sankey Filters from Table Selection
**What:** Clicking a row in the Links table now filters the Sankey diagram to show only the guns connected to that incident and their full network
**How:** Added `edges_for_sankey` reactive that reads `input$links_tbl_rows_selected` and filters edges; table uses single-row selection

---

### Layout & Footer

#### Footer Moved to Instructions Page Only
**What:** BJA disclaimer footer now appears only on the Instructions tab, not on data tabs
**Why:** Fixed footer was overlapping charts; `page_navbar` footer was rendering mid-page on some tabs

#### Date Range Input Readability
**What:** Date range inputs now stack vertically in the sidebar with full-width inputs
**Why:** At sidebar width, side-by-side date inputs were too narrow to show the selected dates
**How:** CSS flexbox override on `.input-daterange`

---

## V2 Updates (Previous)

### 1. Global Sidebar Filters
Filters appear on all tabs via sidebar layout

### 2. Clear Filters Button
Resets all filters to defaults

### 3. Renamed "Event Type" → "Incident Type"
Filter label updated; internal data column unchanged

### 4. Updated Footer Disclaimer
New grant number per BJA requirements (15PBJA-24-GK-04259-BSCI)

### 5. Updated Instructions Tab
Reflects checkbox controls, Clear Filters bullet, User Guide placeholder

### 6. Modal Disclaimer Matches Header
Welcome modal warning text matches header banner

### 7. NIBIN Tab: Minimum Incidents Filter
Slider control (1-10, default 2) filters Sankey to guns meeting threshold

### 8. Gun Selector Searchability
Configured with `searchField` and `searchConjunction` options

---

## Testing Checklist

After deploying, verify:

- [ ] Sidebar is hidden on Instructions tab, visible on all other tabs
- [ ] Sidebar toggle arrow opens/closes sidebar manually on any tab
- [ ] Incident type checkboxes filter charts when unchecked
- [ ] Clear Filters button resets all controls and updates charts
- [ ] Accidental and Justified types show with distinct colors on Overview trend chart
- [ ] Accidental and Justified types show with distinct colors on Map (not grey)
- [ ] Tables show "Incident Type" column header (not "event_type")
- [ ] No "Confirmed Hits" language anywhere in the app
- [ ] "Links" is capitalized in NIBIN table title
- [ ] Beat boundaries display on map when "Show beats" is checked
- [ ] Clicking a row in the Links table filters the Sankey diagram
- [ ] Date range inputs are readable (not cut off) in sidebar
- [ ] Footer disclaimer appears only on Instructions page
- [ ] All existing functionality still works

---

## Files

- **app.R** — Complete dashboard application
- **CHANGELOG_V2_UPDATES.md** — This summary document
- **README.md** — Project overview and setup instructions
