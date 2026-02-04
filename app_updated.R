# app.R — CGIC POC Dashboard (Updated Version with Global Filters)
# ------------------------------------------------------------------------------------------
# Changes in this version:
# - Global sidebar filters (visible on all tabs)
# - "Clear Filters" button added
# - "Event Type" renamed to "Incident Type"
# - Updated footer disclaimer with new grant number
# - Instructions text updated to reflect checkbox controls
# - Modal disclaimer matches header warning
# - NIBIN tab: Added minimum incidents filter
# - Gun selector made explicitly searchable
# ------------------------------------------------------------------------------------------

# Load packages with error handling
required_packages <- c(
  "shiny",
  "bslib",
  "DT",
  "leaflet",
  "leaflet.extras",
  "plotly",

  "networkD3",
  "readr",
  "dplyr",
  "lubridate",
  "tidyr",
  "scales",
  "htmlwidgets",
  "stringr",
  "shinycssloaders"
)

missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages) > 0) {
  message(
    "Installing missing packages: ",
    paste(missing_packages, collapse = ", ")
  )
  install.packages(missing_packages)
}

library(shiny)
library(bslib)
library(DT)
library(leaflet)
library(leaflet.extras)
library(plotly)
library(networkD3)
library(readr)
library(dplyr)
library(lubridate)
library(tidyr)
library(scales)
library(htmlwidgets)
library(stringr)
library(shinycssloaders)

# ---- Configuration ----
config <- list(
  MAX_GUNS = 12,
  MAX_INC_PER_GUN = 4,
  MIN_DEGREE = 2,
  TOP_N_GUNS_TREND = 6,
  map = list(
    default_zoom = 10,
    heat_blur = 20,
    heat_radius = 15
  ),
  ui = list(
    spinner_type = 6,
    table_height = 360
  )
)

# ---- CGIC Brand Palette ----
CGIC <- list(
  navy = "#1a204b",
  gold = "#eabe3f",
  dkgrey = "#6b7079",
  maroon = "#5f2342",
  green = "#1a4b2e",
  blue = "#4e6ab2",
  light = "#E8E8E8",
  white = "#ffffff"
)

brand_colors <- c(CGIC$blue, CGIC$gold, CGIC$maroon, CGIC$green, CGIC$navy)

pal <- colorFactor(
  c(CGIC$maroon, CGIC$gold, CGIC$blue),
  levels = c("Homicide", "Non-Fatal Shooting", "Shots Fired"),
  na.color = CGIC$dkgrey
)

# ---- Bootstrap Theme ----
theme <- bs_theme(
  version = 5,
  base_font = bslib::font_google("Libre Franklin"),
  heading_font = bslib::font_google("Roboto Condensed"),
  bg = CGIC$light,
  fg = CGIC$navy,
  primary = CGIC$navy,
  secondary = CGIC$gold,
  success = CGIC$green,
  info = CGIC$blue,
  warning = CGIC$gold,
  danger = CGIC$maroon
)

# ---- Brand Helpers ----
plot_brand <- function(p) {
  p %>%
    layout(
      colorway = brand_colors,
      paper_bgcolor = CGIC$light,
      plot_bgcolor = CGIC$light,
      font = list(family = "Libre Franklin", color = CGIC$navy),
      title = list(
        font = list(family = "Roboto Condensed", size = 18, color = CGIC$navy)
      ),
      legend = list(
        orientation = "h",
        x = 0,
        y = -0.1,
        bgcolor = "rgba(0,0,0,0)",
        bordercolor = "rgba(0,0,0,0)"
      ),
      hoverlabel = list(
        bgcolor = CGIC$white,
        bordercolor = CGIC$navy,
        font = list(color = CGIC$navy)
      )
    )
}

brand_title <- function(p, text) {
  p %>%
    layout(
      title = list(text = text, x = 0, xanchor = "left"),
      margin = list(t = 56)
    )
}

safe_read_csv <- function(file_path, ...) {
  tryCatch(
    {
      if (!file.exists(file_path)) {
        warning(paste("File not found:", file_path))
        return(data.frame())
      }
      read_csv(file_path, ...)
    },
    error = function(e) {
      warning(paste("Error loading", basename(file_path), ":", e$message))
      return(data.frame())
    }
  )
}

validate_data <- function(df, required_cols, data_name = "data") {
  if (nrow(df) == 0) {
    warning(paste("No data found in", data_name))
    return(FALSE)
  }

  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    warning(paste(
      "Missing required columns in",
      data_name,
      ":",
      paste(missing, collapse = ", ")
    ))
    return(FALSE)
  }
  TRUE
}

# ---- Data Loading ----
poc <- "data/poc"

incidents_view <- safe_read_csv(
  file.path(poc, "table_incidents.csv"),
  col_types = cols(
    incident_id = col_character(),
    occurred_dt = col_datetime(format = ""),
    month = col_datetime(format = ""),
    event_type = col_character(),
    beat = col_character(),
    sector = col_character(),
    casings_n = col_integer(),
    outside_agency = col_integer(),
    lon = col_double(),
    lat = col_double()
  )
)

validate_data(
  incidents_view,
  c("incident_id", "occurred_dt", "month", "event_type", "beat", "lon", "lat"),
  "incidents"
)

leads_view <- safe_read_csv(
  file.path(poc, "table_leads.csv"),
  col_types = cols(
    lead_id = col_character(),
    lead_generated_dt = col_datetime(format = ""),
    month = col_datetime(format = ""),
    is_hit = col_integer(),
    acquisition_id = col_character(),
    acquisition_dt = col_datetime(format = ""),
    tat_days = col_double(),
    source = col_character(),
    firearm_id = col_character()
  )
)

validate_data(
  leads_view,
  c("lead_id", "month", "is_hit", "tat_days", "firearm_id"),
  "leads"
)

acquisitions_view <- safe_read_csv(
  file.path(poc, "table_acquisitions.csv"),
  col_types = cols(
    acquisition_id = col_character(),
    acquisition_dt = col_datetime(format = ""),
    month = col_datetime(format = ""),
    source = col_character(),
    incident_id = col_character(),
    firearm_id = col_character()
  )
)

validate_data(
  acquisitions_view,
  c("acquisition_id", "month", "source"),
  "acquisitions"
)

links_view <- safe_read_csv(
  file.path(poc, "table_lead_incident_links.csv"),
  col_types = cols(
    lead_id = col_character(),
    incident_id = col_character(),
    firearm_id = col_character(),
    occurred_dt = col_datetime(format = "")
  )
)

validate_data(links_view, c("lead_id", "incident_id", "firearm_id"), "links")

# ---- Sector Generation ----
build_big_sectors <- function(df, k = 6, pad_frac = 0.07, seed = 42) {
  if (nrow(df) == 0 || !all(c("lon", "lat") %in% names(df))) {
    return(list(polys = data.frame(), labels = data.frame()))
  }

  set.seed(seed)
  pts <- df %>%
    dplyr::filter(!is.na(lon), !is.na(lat)) %>%
    dplyr::distinct(lon, lat)

  if (nrow(pts) < k) {
    warning("Not enough unique points for requested sectors")
    return(list(polys = data.frame(), labels = data.frame()))
  }

  tryCatch(
    {
      km <- kmeans(pts[, c("lon", "lat")], centers = k, nstart = 20)
      centers <- tibble::tibble(
        sector = sprintf("S%02d", seq_len(k)),
        lon = km$centers[, 1],
        lat = km$centers[, 2]
      )

      rx <- range(df$lon, na.rm = TRUE)
      ry <- range(df$lat, na.rm = TRUE)
      pad_x <- diff(rx) * pad_frac
      pad_y <- diff(ry) * pad_frac
      bb <- c(rx[1] - pad_x, rx[2] + pad_x, ry[1] - pad_y, ry[2] + pad_y)

      vor <- deldir::deldir(centers$lon, centers$lat, rw = bb)
      tiles <- deldir::tile.list(vor)

      polys <- purrr::map2_dfr(
        tiles,
        centers$sector,
        ~ tibble::tibble(
          sector = .y,
          lon = c(.x$x, .x$x[1]),
          lat = c(.x$y, .x$y[1])
        )
      )

      list(polys = polys, labels = centers)
    },
    error = function(e) {
      warning("Error creating sectors: ", e$message)
      list(polys = data.frame(), labels = data.frame())
    }
  )
}

sectors_big <- build_big_sectors(incidents_view, k = 6)
sector_polys <- sectors_big$polys
sector_labels <- sectors_big$labels

# ---- Brand Logo ----
brand_logo <- if (file.exists("www/CGIC Logo_Primary.png")) {
  div(
    style = "background-color: #f3f3f3ff; padding: 6px 12px; border-radius: 4px; margin-right: 15px;",
    tags$img(
      src = "CGIC Logo_Primary.png",
      class = "cgic-logo",
      alt = "Crime Gun Intelligence Centers"
    )
  )
} else {
  NULL
}

# ---- UI Components ----

# Instructions tab content (updated to reflect checkbox controls)
instructions_content <- div(
  class = "container",
  style = "max-width:1100px;",
  div(
    class = "polished-card",
    h2("CGIC Dashboard — Instructions & Guidance"),
    p(
      "The primary goal of a Crime Gun Intelligence Center (CGIC) is to rapidly identify and investigate armed violent offenders using real-time crime gun evidence, such as cartridge casings. This mock dashboard serves as a starting point for agencies to develop their own dashboards and visualizations. Agencies are encouraged to customize the template to fit their operational needs—for example, by modifying table columns or updating visualizations."
    ),
    h4("How to use this dashboard"),
    tags$ul(
      tags$li(
        "Use the filters in the sidebar (left) to adjust time ranges, incident types, and beats. All charts, the map, and the tables update together across all tabs."
      ),
      tags$li(
        "On the Map & Incidents tab, use the checkboxes to toggle ",
        strong("Points"),
        ", ",
        strong("Heatmap"),
        ", and ",
        strong("Sector boundaries"),
        " on or off."
      ),
      tags$li(
        "On the NIBIN & Sankey tab, use the gun selector dropdown to filter the links table and highlight associated incidents on the map. Use the ",
        em("Clear selection"),
        " button to reset."
      ),
      tags$li(
        "Use the ",
        strong("Clear Filters"),
        " button in the sidebar to reset all filters to their default values."
      )
    ),
    h4("User Guide"),
    p(
      "For a detailed description of dashboard functionality and capabilities, please access the ",
      a(
        href = "#",
        "User Guide",
        target = "_blank"
      ),
      "."
    ),
    h4("Questions?"),
    p(
      "Visit ",
      a(
        href = "https://www.crimegunintelcenters.org",
        "crimegunintelcenters.org",
        target = "_blank"
      ),
      " or email ",
      a(
        href = "mailto:tta@policinginstitute.org",
        "tta@policinginstitute.org"
      ),
      "."
    )
  )
)

# ---- Navbar brand with CGIC logo ----
brand <- div(
  class = "cgic-brand d-flex align-items-center",
  brand_logo,
  span(
    "NPI CGIC Dashboard Demo",
    style = "color: #eabe3f; font-weight: 600; font-size: 18px;"
  )
)

# ---- Global Sidebar Panel (appears on all tabs) ----
global_sidebar <- sidebarPanel(
  width = 2,
  div(
    class = "sidebar-filters",
    h4("Filters"),
    dateRangeInput(
      "date_range",
      "Month range",
      start = if (nrow(incidents_view) > 0) {
        as_date(floor_date(
          min(incidents_view$month, na.rm = TRUE),
          "month"
        ))
      } else {
        as_date("2023-01-01")
      },
      end = if (nrow(incidents_view) > 0) {
        as_date(floor_date(
          max(incidents_view$month, na.rm = TRUE),
          "month"
        ))
      } else {
        as_date("2023-12-01")
      },
      min = if (nrow(incidents_view) > 0) {
        as_date(floor_date(
          min(incidents_view$month, na.rm = TRUE),
          "month"
        ))
      } else {
        as_date("2023-01-01")
      },
      max = if (nrow(incidents_view) > 0) {
        as_date(floor_date(
          max(incidents_view$month, na.rm = TRUE),
          "month"
        ))
      } else {
        as_date("2023-12-01")
      },
      startview = "year",
      format = "yyyy-mm-01"
    ),
    selectizeInput(
      "incident_type",
      "Incident type",
      choices = if (nrow(incidents_view) > 0) {
        sort(unique(incidents_view$event_type))
      } else {
        character(0)
      },
      selected = if (nrow(incidents_view) > 0) {
        intersect(
          c("Shots Fired", "Non-Fatal Shooting", "Homicide"),
          unique(incidents_view$event_type)
        )
      } else {
        character(0)
      },
      multiple = TRUE
    ),
    selectizeInput(
      "beat",
      "Beat",
      choices = if (nrow(incidents_view) > 0) {
        sort(unique(incidents_view$beat))
      } else {
        character(0)
      },
      multiple = TRUE
    ),
    checkboxInput("hits_only", "Hits only (confirmed)", value = FALSE),
    hr(),
    actionButton(
      "clear_filters",
      "Clear Filters",
      class = "btn btn-outline-secondary btn-sm",
      style = "width: 100%;"
    )
  )
)

# ---- Main UI ----
ui <- tagList(
  tags$head(
    tags$style(HTML(
      "
    /* ===== LEVEL 3 POLISH STYLES ===== */
    
    /* Card System */
    .chart-card {
      background: #ffffff;
      border: 1px solid #e0e0e0;
      border-radius: 6px;
      padding: 18px;
      margin-bottom: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
      transition: box-shadow 0.3s ease;
    }
    .chart-card:hover {
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    }

    .polished-card {
      background: #ffffff;
      border: 1px solid #e0e0e0;
      border-radius: 6px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
      transition: box-shadow 0.3s ease;
    }
    .polished-card:hover {
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    }

    /* Section Headers */
    .section-header {
      font-family: 'Roboto Condensed', sans-serif;
      font-size: 26px;
      font-weight: 700;
      color: #1a204b;
      margin: 25px 0 18px 0;
      padding-bottom: 8px;
      border-bottom: 2px solid #eabe3f;
    }

    /* Tab Hover Effects */
    .nav-tabs .nav-link,
    .navbar-nav .nav-link {
      transition: all 0.3s ease;
    }
    .nav-tabs .nav-link:hover,
    .navbar-nav .nav-link:hover {
      transform: translateY(-2px);
      background-color: rgba(234, 190, 63, 0.12);
    }
    .nav-tabs .nav-link.active,
    .navbar-nav .nav-link.active {
      background-color: rgba(234, 190, 63, 0.08);
    }

    /* Sidebar Filter Card */
    .sidebar-filters {
      background: #ffffff;
      border: 1px solid #e0e0e0;
      border-radius: 6px;
      padding: 18px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }
    .sidebar-filters h4 {
      font-size: 17px;
      font-weight: 600;
      color: #1a204b;
      margin-bottom: 16px;
      padding-bottom: 8px;
      border-bottom: 2px solid #eabe3f;
    }

    /* Map controls */
    .map-controls-bar {
      background: #ffffff;
      border: 1px solid #e0e0e0;
      border-radius: 6px;
      padding: 12px 18px;
      margin-bottom: 15px;
      display: flex;
      align-items: center;
      gap: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }
    .map-controls-bar h4 {
      margin: 0;
      font-size: 17px;
      color: #1a204b;
      font-weight: 600;
    }

    /* Info banners */
    .info-banner {
      background-color: #d1ecf1;
      border: 1px solid #bee5eb;
      border-left: 4px solid #17a2b8;
      padding: 12px 18px;
      margin-bottom: 20px;
      border-radius: 4px;
      color: #0c5460;
    }

    /* Helper text */
    .helper-text {
      font-size: 13px;
      color: #6b7079;
      font-style: italic;
      margin-top: 8px;
    }

    /* Footer */
    .app-footer{
      background:#f5f5f5;
      border-top:3px solid #eabe3f;
      color:#1a204b;
      padding:12px 16px;
      font-size:12px;
      line-height:1.35;
    }
    .spinner-container { min-height: 300px; }

    /* Navbar brand + logo */
    .navbar {
      background: linear-gradient(135deg, #1a204b 0%, #2a3558 100%);
      box-shadow: 0 2px 8px rgba(0,0,0,0.15);
      min-height:60px;
    }
    .navbar .navbar-brand {
      display:flex; align-items:center; gap: 1.5rem;
      padding-top:0; padding-bottom:0;
      transition: transform 0.2s ease;
    }
    .navbar .navbar-brand:hover {
      transform: scale(1.02);
    }
    .navbar .navbar-brand .cgic-logo {
      height: 55px;
      max-width: 450px;
      width: auto;
      object-fit: contain;
    }
    @media (max-width:576px){
      .navbar .navbar-brand .cgic-logo { height: 35px; max-width: 200px; }
      .cgic-brand span { display:none; }
    }

    /* Navbar tabs */
    .navbar-nav > li > a { 
      padding-top:18px; 
      padding-bottom:18px;
      color: rgba(255,255,255,0.9);
      font-weight: 500;
    }
    .navbar .nav-link { 
      padding-top:.9rem; 
      padding-bottom:.9rem;
      color: rgba(255,255,255,0.9);
    }
    .navbar-nav .nav-link.active {
      color: #eabe3f !important;
      font-weight: 600;
    }
    
    /* NIBIN controls styling */
    .nibin-controls {
      background: #f8f9fa;
      border: 1px solid #e0e0e0;
      border-radius: 6px;
      padding: 12px 15px;
      margin-bottom: 15px;
    }
  "
    ))
  ),

  navbarPage(
    title = brand,
    theme = theme,

    header = div(
      class = "container-fluid",
      div(
        class = "alert alert-warning mb-2",
        style = "max-width: 1400px; margin: 0 auto;",
        "⚠️ NOTE: The data shown in this mock dashboard is manufactured and not representative of any actual city, locality, or jurisdiction."
      )
    ),

    # Instructions Tab (standalone, no sidebar needed)
    tabPanel(
      "📋 Instructions",
      instructions_content
    ),

    # All other tabs wrapped in sidebarLayout for global filters
    tabPanel(
      "📊 Overview",
      sidebarLayout(
        global_sidebar,
        mainPanel(
          width = 10,

          div(class = "section-header", "📈 Incident Trends"),
          fluidRow(
            column(
              6,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("incidents_trend", height = "280px"),
                  type = config$ui$spinner_type
                ),
                tags$small(
                  class = "helper-text",
                  "Incidents = Shots Fired, Non-Fatal Shooting, Homicide."
                )
              )
            ),
            column(
              6,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("entries_source", height = "280px"),
                  type = config$ui$spinner_type
                ),
                tags$small(
                  class = "helper-text",
                  "NIBIN entries by source: Scene (cartridge cases) vs Test-Fire (seized firearm test)."
                )
              )
            )
          ),

          div(class = "section-header", "🎯 NIBIN Performance"),
          fluidRow(
            column(
              4,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("leads_hits", height = "280px"),
                  type = config$ui$spinner_type
                ),
                tags$small(
                  class = "helper-text",
                  "Leads = NIBIN correlation notifications; Hits = confirmed links vetted by personnel."
                )
              )
            ),
            column(
              4,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("tat_line_p48", height = "280px"),
                  type = config$ui$spinner_type
                ),
                tags$small(
                  class = "helper-text",
                  "Lead turnaround (Acquisition → Lead); KPI = % of leads generated ≤ 48 hours."
                )
              )
            ),
            column(
              4,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("casings_combo", height = "280px"),
                  type = config$ui$spinner_type
                ),
                tags$small(
                  class = "helper-text",
                  "Bars = casings collected; Line = % scenes with any casings."
                )
              )
            )
          )
        )
      )
    ),

    tabPanel(
      "🗺️ Map & Incidents",
      sidebarLayout(
        global_sidebar,
        mainPanel(
          width = 10,

          div(
            class = "map-controls-bar",
            h4("Incident Map"),
            checkboxInput("show_points", "Show Points", value = FALSE),
            checkboxInput("show_heatmap", "Show Heatmap", value = FALSE),
            checkboxInput("show_sectors", "Show sectors", value = FALSE)
          ),

          div(
            class = "chart-card",
            withSpinner(
              leafletOutput("incidents_map", height = 440),
              type = config$ui$spinner_type
            )
          ),

          br(),

          div(
            class = "polished-card",
            h4("Incidents"),
            div(
              style = paste0(
                "max-height: ",
                config$ui$table_height + 60,
                "px; overflow-y: auto; border: 1px solid #eee; padding: 6px;"
              ),
              withSpinner(
                DTOutput("incidents_tbl"),
                type = config$ui$spinner_type
              )
            )
          )
        )
      )
    ),

    tabPanel(
      "✅ Clearance",
      sidebarLayout(
        global_sidebar,
        mainPanel(
          width = 10,

          div(
            class = "info-banner",
            tags$strong("Demo only:"),
            " If your data includes clearance fields, charts will use them; otherwise synthetic demo values are used."
          ),

          div(class = "section-header", "Clearance Analysis"),

          fluidRow(
            column(
              6,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("clr_rate_by_type", height = "320px"),
                  type = config$ui$spinner_type
                )
              )
            ),
            column(
              6,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("clr_days_by_type", height = "320px"),
                  type = config$ui$spinner_type
                )
              )
            )
          )
        )
      )
    ),

    tabPanel(
      "🔗 NIBIN & Sankey",
      sidebarLayout(
        global_sidebar,
        mainPanel(
          width = 10,

          # NIBIN-specific controls
          div(
            class = "nibin-controls",
            fluidRow(
              column(
                4,
                sliderInput(
                  "min_incidents",
                  "Minimum incidents per gun:",
                  min = 1,
                  max = 10,
                  value = 2,
                  step = 1
                )
              ),
              column(
                4,
                selectizeInput(
                  "gun_selector",
                  "Select Gun:",
                  choices = NULL,
                  selected = NULL,
                  options = list(
                    placeholder = "Choose a gun to filter...",
                    searchField = c("label", "value"),
                    searchConjunction = "or"
                  )
                )
              ),
              column(
                4,
                div(
                  style = "padding-top: 25px;",
                  actionButton(
                    "clear_gun",
                    "Clear Gun Selection",
                    class = "btn btn-sm btn-outline-secondary"
                  ),
                  uiOutput("gun_selected_label", inline = TRUE)
                )
              )
            )
          ),

          fluidRow(
            column(
              7,
              div(
                class = "chart-card",
                h4("Gun ↔ Incident Linkages (Confirmed Hits)"),
                tags$small(
                  class = "helper-text",
                  "Use the gun selector above to filter the table and highlight incidents on the map."
                ),
                withSpinner(
                  sankeyNetworkOutput("sankey", height = "450px"),
                  type = config$ui$spinner_type
                )
              )
            ),
            column(
              5,
              div(
                class = "polished-card",
                h4(uiOutput("links_title")),
                div(
                  style = "max-height: 560px; overflow-y: auto; border: 1px solid #eee; padding: 6px;",
                  withSpinner(
                    DTOutput("links_tbl"),
                    type = config$ui$spinner_type
                  )
                )
              )
            )
          ),

          br(),

          fluidRow(
            column(
              6,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("hits_by_gun", height = "300px"),
                  type = config$ui$spinner_type
                ),
                tags$small(
                  class = "helper-text",
                  "Total confirmed hits for most active guns; individual gun view shows monthly hit pattern."
                )
              )
            ),
            column(
              6,
              div(
                class = "chart-card",
                withSpinner(
                  plotlyOutput("links_over_time", height = "300px"),
                  type = config$ui$spinner_type
                ),
                tags$small(
                  class = "helper-text",
                  "Bars = unique links; Line = average incidents per linked gun."
                )
              )
            )
          )
        )
      )
    )
  ),

  # Welcome Modal (disclaimer matches header warning)
  tags$div(
    class = "modal fade",
    id = "welcomeModal",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog modal-lg",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          style = "background-color:#1a204b; color: white;",
          tags$h4(class = "modal-title", "🎯 Welcome to the CGIC Dashboard"),
          tags$button(
            type = "button",
            class = "btn-close btn-close-white",
            `data-bs-dismiss` = "modal"
          )
        ),
        tags$div(
          class = "modal-body",
          p(
            "This interactive dashboard helps you analyze crime gun intelligence data and NIBIN leads."
          ),

          h5("Quick Overview:"),
          tags$ul(
            tags$li(strong("Instructions:"), " How to use this dashboard"),
            tags$li(strong("Overview:"), " Key metrics and trends"),
            tags$li(strong("Map & Incidents:"), " Geographic analysis"),
            tags$li(strong("Clearance:"), " Case clearance tracking"),
            tags$li(strong("NIBIN & Sankey:"), " Gun-incident networks")
          ),

          h5("💡 Tips:"),
          tags$ul(
            tags$li(
              "Use filters in the sidebar to refine data (filters appear on all tabs)"
            ),
            tags$li("Toggle map layers to see different views"),
            tags$li("Select guns to filter network connections"),
            tags$li("Hover over charts for detailed information"),
            tags$li("Use the 'Clear Filters' button to reset all filters")
          ),

          div(
            class = "alert alert-warning",
            style = "margin-top: 15px;",
            tags$strong("⚠️ Note:"),
            " The data shown in this mock dashboard is manufactured and not representative of any actual city, locality, or jurisdiction."
          )
        ),
        tags$div(
          class = "modal-footer",
          tags$button(
            type = "button",
            class = "btn btn-secondary",
            `data-bs-dismiss` = "modal",
            onclick = "localStorage.setItem('cgic_welcome_seen', 'true');",
            "Don't Show Again"
          ),
          tags$button(
            type = "button",
            class = "btn btn-primary",
            `data-bs-dismiss` = "modal",
            "Get Started"
          )
        )
      )
    )
  ),

  # Auto-show modal on first visit
  tags$script(HTML(
    "
    document.addEventListener('DOMContentLoaded', function() {
      if (!localStorage.getItem('cgic_welcome_seen')) {
        var modal = new bootstrap.Modal(document.getElementById('welcomeModal'));
        modal.show();
      }
    });
  "
  )),

  # Updated footer with new grant number
  div(
    class = "app-footer",
    HTML(
      "This project is funded through a grant from the Bureau of Justice Assistance, Office of Justice Programs, U.S. Department of Justice. Neither the U.S. Department of Justice nor any of its components operate, control, are responsible for, or necessarily endorse, this Web site (including, without limitation, its content, technical infrastructure, and policies, and any services or tools provided). This project was supported by Grant No. 15PBJA-24-GK-04259-BSCI awarded by the Bureau of Justice Assistance."
    )
  )
)

# ---- Server Function ----
server <- function(input, output, session) {
  # Reactive values
  selected_gun <- reactiveVal(NULL)

  selected_gun_id <- reactive({
    g <- selected_gun()
    if (is.null(g)) {
      return(NULL)
    }
    sub("^Gun:", "", g)
  })

  # Input validation
  observe({
    req(input$date_range)
    if (
      length(input$date_range) == 2 && input$date_range[1] > input$date_range[2]
    ) {
      showNotification("Start date must be before end date", type = "error")
      updateDateRangeInput(
        session,
        "date_range",
        start = input$date_range[2],
        end = input$date_range[1]
      )
    }
  })

  # Clear Filters button handler
  observeEvent(input$clear_filters, {
    # Reset date range to full range
    updateDateRangeInput(
      session,
      "date_range",
      start = if (nrow(incidents_view) > 0) {
        as_date(floor_date(min(incidents_view$month, na.rm = TRUE), "month"))
      } else {
        as_date("2023-01-01")
      },
      end = if (nrow(incidents_view) > 0) {
        as_date(floor_date(max(incidents_view$month, na.rm = TRUE), "month"))
      } else {
        as_date("2023-12-01")
      }
    )

    # Reset incident type to defaults
    updateSelectizeInput(
      session,
      "incident_type",
      selected = if (nrow(incidents_view) > 0) {
        intersect(
          c("Shots Fired", "Non-Fatal Shooting", "Homicide"),
          unique(incidents_view$event_type)
        )
      } else {
        character(0)
      }
    )

    # Clear beat selection
    updateSelectizeInput(session, "beat", selected = character(0))

    # Uncheck hits only
    updateCheckboxInput(session, "hits_only", value = FALSE)

    # Reset min incidents slider
    updateSliderInput(session, "min_incidents", value = 2)

    # Clear gun selection
    selected_gun(NULL)
    updateSelectizeInput(session, "gun_selector", selected = "ALL")

    showNotification("Filters cleared", type = "message", duration = 2)
  })

  in_range <- reactive({
    req(input$date_range)
    function(x_month) {
      if (is.null(x_month) || all(is.na(x_month))) {
        return(rep(FALSE, length(x_month)))
      }
      as_date(x_month) >= input$date_range[1] &
        as_date(x_month) <= input$date_range[2]
    }
  })

  # Filtered data reactives (updated to use incident_type input)
  incidents_f <- reactive({
    if (nrow(incidents_view) == 0) {
      return(incidents_view)
    }

    tryCatch(
      {
        incidents_view %>%
          filter(
            in_range()(month),
            event_type %in%
              (if (length(input$incident_type)) {
                input$incident_type
              } else {
                unique(event_type)
              }),
            beat %in% (if (length(input$beat)) input$beat else unique(beat))
          )
      },
      error = function(e) {
        showNotification("Error filtering incidents data", type = "error")
        incidents_view[0, ]
      }
    )
  })

  lead_ids_by_incfilter <- reactive({
    if (nrow(links_view) == 0) {
      return(character(0))
    }

    inc_ids <- incidents_f()$incident_id
    if (!length(inc_ids)) {
      return(character(0))
    }

    tryCatch(
      {
        links_view %>%
          filter(incident_id %in% inc_ids) %>%
          pull(lead_id) %>%
          unique()
      },
      error = function(e) {
        character(0)
      }
    )
  })

  acquisitions_f <- reactive({
    if (nrow(acquisitions_view) == 0) {
      return(acquisitions_view)
    }

    tryCatch(
      {
        d <- acquisitions_view %>% filter(in_range()(month))

        if (length(input$beat) || length(input$incident_type)) {
          inc_ids <- incidents_f()$incident_id
          if (length(inc_ids)) {
            d <- d %>% filter(is.na(incident_id) | incident_id %in% inc_ids)
          }
        }
        d
      },
      error = function(e) {
        showNotification("Error filtering acquisitions data", type = "error")
        acquisitions_view[0, ]
      }
    )
  })

  leads_f <- reactive({
    if (nrow(leads_view) == 0) {
      return(leads_view)
    }

    tryCatch(
      {
        d <- leads_view %>% filter(in_range()(month))

        if (isTRUE(input$hits_only)) {
          d <- d %>% filter(is_hit == 1)
        }

        if (length(input$beat) || length(input$incident_type)) {
          keep <- lead_ids_by_incfilter()
          d <- if (length(keep)) d %>% filter(lead_id %in% keep) else d[0, ]
        }
        d
      },
      error = function(e) {
        showNotification("Error filtering leads data", type = "error")
        leads_view[0, ]
      }
    )
  })

  # Clearance data generation
  inc_clr <- reactive({
    d <- incidents_f()
    if (nrow(d) == 0) {
      return(d)
    }

    if (all(c("clearance_type", "clearance_dt") %in% names(d))) {
      d_with_clr <- d %>% mutate(clearance_type = as.character(clearance_type))
    } else {
      set.seed(42)
      types <- sample(
        c("Open", "Arrest", "Exception", "Unfounded"),
        size = nrow(d),
        replace = TRUE,
        prob = c(0.55, 0.30, 0.10, 0.05)
      )

      ttc <- ifelse(
        types == "Open",
        NA_real_,
        pmax(1, round(rnorm(nrow(d), mean = 35, sd = 15)))
      )

      d_with_clr <- d %>%
        mutate(
          clearance_type = types,
          clearance_dt = if_else(
            is.na(ttc),
            as.POSIXct(NA),
            occurred_dt + days(ttc)
          ),
          ttc_days = as.numeric(difftime(
            clearance_dt,
            occurred_dt,
            units = "days"
          ))
        )
    }

    if (!"ttc_days" %in% names(d_with_clr)) {
      d_with_clr <- d_with_clr %>%
        mutate(
          ttc_days = as.numeric(difftime(
            clearance_dt,
            occurred_dt,
            units = "days"
          ))
        )
    }

    d_with_clr
  })

  # Edge computation
  compute_edges <- function(leads_data, links_data) {
    if (nrow(leads_data) == 0 || nrow(links_data) == 0) {
      return(data.frame())
    }

    hits <- leads_data %>%
      filter(is_hit == 1, !is.na(firearm_id)) %>%
      select(lead_id, firearm_id)

    if (nrow(hits) == 0) {
      return(data.frame())
    }

    links_data %>%
      inner_join(hits, by = c("lead_id", "firearm_id")) %>%
      distinct(firearm_id, incident_id) %>%
      left_join(
        incidents_view %>% select(incident_id, month, beat, sector),
        by = "incident_id"
      )
  }

  # Base edges (not affected by gun selection)
  edges_base <- reactive({
    compute_edges(leads_f(), links_view)
  })

  # Slim edges for Sankey diagram (updated to respect min_incidents filter)
  edges_slim <- reactive({
    if (nrow(leads_f()) == 0 || nrow(links_view) == 0) {
      return(data.frame())
    }

    # Get min_incidents value (default to 2 if not set)
    min_inc <- if (!is.null(input$min_incidents)) input$min_incidents else 2

    tryCatch(
      {
        hit_leads <- leads_f() %>%
          filter(is_hit == 1, !is.na(firearm_id)) %>%
          select(lead_id, firearm_id)

        if (nrow(hit_leads) == 0) {
          return(data.frame())
        }

        edges_all <- links_view %>%
          inner_join(hit_leads, by = c("lead_id", "firearm_id")) %>%
          distinct(firearm_id, incident_id)

        if (nrow(edges_all) == 0) {
          return(data.frame())
        }

        set.seed(1)
        capped <- edges_all %>%
          group_by(firearm_id) %>%
          mutate(.rnd = runif(n())) %>%
          arrange(firearm_id, .rnd) %>%
          slice_head(n = config$MAX_INC_PER_GUN) %>%
          ungroup() %>%
          select(-.rnd)

        # Apply minimum incidents filter (use min_inc from input)
        top_guns <- capped %>%
          count(firearm_id, name = "deg") %>%
          filter(deg >= min_inc) %>%
          arrange(desc(deg)) %>%
          slice_head(n = config$MAX_GUNS) %>%
          pull(firearm_id)

        capped %>% filter(firearm_id %in% top_guns)
      },
      error = function(e) {
        showNotification("Error processing network data", type = "warning")
        data.frame()
      }
    )
  })

  # Update gun selector choices based on available guns
  observe({
    ed <- edges_slim()
    if (nrow(ed) > 0) {
      gun_choices <- ed %>%
        count(firearm_id, name = "incidents") %>%
        arrange(desc(incidents)) %>%
        pull(firearm_id)

      # Create named vector with incident counts
      gun_names <- paste0(
        gun_choices,
        " (",
        ed %>%
          count(firearm_id, name = "incidents") %>%
          arrange(desc(incidents)) %>%
          pull(incidents),
        " incidents)"
      )
      names(gun_choices) <- gun_names

      # Add "All Guns" option at the top
      all_choices <- c("All Guns" = "ALL", gun_choices)

      updateSelectizeInput(
        session,
        "gun_selector",
        choices = all_choices,
        selected = "ALL"
      )
    } else {
      updateSelectizeInput(session, "gun_selector", choices = character(0))
    }
  })

  # Handle gun selector dropdown changes
  observeEvent(
    input$gun_selector,
    {
      if (!is.null(input$gun_selector) && input$gun_selector != "") {
        if (input$gun_selector == "ALL") {
          # Clear selection to show all guns
          selected_gun(NULL)
          leafletProxy("incidents_map") %>% clearGroup("gun_sel")
        } else {
          # Select specific gun
          gun_name <- paste0("Gun:", input$gun_selector)
          selected_gun(gun_name)

          # Highlight incidents on map
          tryCatch(
            {
              leafletProxy('incidents_map') %>% clearGroup("gun_sel")

              inc_ids <- links_view %>%
                filter(firearm_id == input$gun_selector) %>%
                pull(incident_id) %>%
                unique()

              df <- incidents_f() %>% filter(incident_id %in% inc_ids)
              if (nrow(df) > 0) {
                leafletProxy("incidents_map") %>%
                  addCircleMarkers(
                    data = df,
                    ~lon,
                    ~lat,
                    radius = 11,
                    color = "red",
                    weight = 2,
                    fill = FALSE,
                    group = "gun_sel"
                  )
              }

              showNotification(
                paste("Selected gun:", input$gun_selector),
                type = "message",
                duration = 2
              )
            },
            error = function(e) {
              showNotification(
                "Error highlighting gun incidents",
                type = "error"
              )
            }
          )
        }
      }
    },
    ignoreInit = TRUE
  )

  # Clear gun selector when clear button is pressed
  observeEvent(input$clear_gun, {
    selected_gun(NULL)
    updateSelectizeInput(session, "gun_selector", selected = "ALL")
    leafletProxy("incidents_map") %>% clearGroup("gun_sel")
  })

  # ---- Chart Outputs ----
  output$incidents_trend <- renderPlotly({
    d <- incidents_f()
    if (nrow(d) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No data available") %>%
          plot_brand()
      )
    }

    trend_data <- d %>%
      count(month, event_type, name = "n") %>%
      arrange(month)

    if (nrow(trend_data) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No incidents in selected range") %>%
          plot_brand()
      )
    }

    # Use named vector for colors (fixes palette error)
    event_colors <- c(
      "Shots Fired" = CGIC$blue,
      "Non-Fatal Shooting" = CGIC$gold,
      "Homicide" = CGIC$maroon
    )

    plot_ly(
      trend_data,
      x = ~month,
      y = ~n,
      color = ~event_type,
      colors = event_colors,
      type = "scatter",
      mode = "lines+markers",
      hovertemplate = "%{x|%Y-%m}<br>%{fullData.name}: %{y}<extra></extra>"
    ) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Incidents", rangemode = "tozero")
      ) %>%
      brand_title("Shooting Incidents by Type") %>%
      plot_brand()
  })

  output$entries_source <- renderPlotly({
    d <- acquisitions_f()
    if (nrow(d) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No acquisition data available") %>%
          plot_brand()
      )
    }

    source_data <- d %>%
      group_by(month, source) %>%
      summarise(entries = n(), .groups = "drop") %>%
      arrange(month, source) %>%
      mutate(source = factor(source, levels = c("Scene", "Test-Fire")))

    # Use named vector for colors (fixes palette error)
    source_colors <- c("Scene" = CGIC$green, "Test-Fire" = CGIC$blue)

    plot_ly(
      source_data,
      x = ~month,
      y = ~entries,
      color = ~source,
      colors = source_colors,
      type = "bar",
      text = ~entries,
      textposition = "outside",
      hovertemplate = "%{x|%Y-%m}: %{y} %{fullData.name}<extra></extra>"
    ) %>%
      layout(
        barmode = "group",
        xaxis = list(title = ""),
        yaxis = list(title = "NIBIN entries", rangemode = "tozero")
      ) %>%
      brand_title("NIBIN Entries by Source") %>%
      plot_brand()
  })

  output$clr_rate_by_type <- renderPlotly({
    d <- inc_clr()
    if (nrow(d) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No clearance data available") %>%
          plot_brand()
      )
    }

    monthly <- d %>% count(month, clearance_type, name = "n")
    totals <- d %>% count(month, name = "total")

    pct <- monthly %>%
      left_join(totals, by = "month") %>%
      mutate(pct = n / total * 100)

    plot_ly(
      pct,
      x = ~month,
      y = ~pct,
      color = ~clearance_type,
      colors = brand_colors,
      type = "bar",
      hovertemplate = "%{x|%Y-%m}<br>%{fullData.name}: %{y:.1f}%<extra></extra>"
    ) %>%
      layout(
        barmode = "stack",
        xaxis = list(title = ""),
        yaxis = list(
          title = "% of incidents",
          tickformat = ".0f",
          ticksuffix = "%"
        )
      ) %>%
      brand_title("Clearance Rate by Type (Monthly)") %>%
      plot_brand()
  })

  output$clr_days_by_type <- renderPlotly({
    d <- inc_clr() %>%
      filter(!is.na(ttc_days), clearance_type != "Open")

    if (nrow(d) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No clearance time data available") %>%
          plot_brand()
      )
    }

    m <- d %>%
      group_by(month, clearance_type) %>%
      summarise(avg_days = mean(ttc_days, na.rm = TRUE), .groups = "drop") %>%
      arrange(month)

    plot_ly(
      m,
      x = ~month,
      y = ~avg_days,
      color = ~clearance_type,
      colors = brand_colors,
      type = "scatter",
      mode = "lines+markers",
      hovertemplate = "%{x|%Y-%m}<br>%{fullData.name}: %{y:.1f} days<extra></extra>"
    ) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Avg days to clearance", rangemode = "tozero")
      ) %>%
      brand_title("Average Days to Clearance by Type") %>%
      plot_brand()
  })

  output$leads_hits <- renderPlotly({
    lf <- leads_f()
    if (nrow(lf) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No leads data available") %>%
          plot_brand()
      )
    }

    leads_summary <- lf %>%
      group_by(month) %>%
      summarise(
        leads = n(),
        hits = sum(is_hit == 1, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(month)

    plot_ly(leads_summary, x = ~month) %>%
      add_lines(
        y = ~leads,
        name = "Leads",
        mode = "lines+markers",
        line = list(width = 3, color = CGIC$blue),
        hovertemplate = "%{x|%Y-%m}: %{y} leads<extra></extra>"
      ) %>%
      add_lines(
        y = ~hits,
        name = "Hits",
        mode = "lines+markers",
        line = list(width = 3, color = CGIC$gold),
        hovertemplate = "%{x|%Y-%m}: %{y} hits<extra></extra>"
      ) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Count", rangemode = "tozero")
      ) %>%
      brand_title("NIBIN Leads & Confirmed Hits") %>%
      plot_brand()
  })

  output$tat_line_p48 <- renderPlotly({
    d <- leads_f()
    if (nrow(d) == 0 || !("tat_days" %in% names(d))) {
      return(
        plot_ly() %>%
          layout(title = "No turnaround time data available") %>%
          plot_brand()
      )
    }

    tat_summary <- d %>%
      group_by(month) %>%
      summarise(
        pct_48h = mean(tat_days <= 2, na.rm = TRUE),
        med_tat = median(tat_days, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(month)

    plot_ly(
      tat_summary,
      x = ~month,
      y = ~pct_48h,
      type = "bar",
      text = ~ scales::percent(pct_48h, accuracy = 1),
      textposition = "outside",
      customdata = ~med_tat,
      hovertemplate = "%{x|%Y-%m}<br>% ≤48h: %{y:.0%}<br>Median days: %{customdata:.1f}<extra></extra>"
    ) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(
          title = "% ≤ 48h",
          tickformat = ".0%",
          rangemode = "tozero"
        ),
        shapes = if (nrow(tat_summary) > 0) {
          list(list(
            type = "line",
            x0 = min(tat_summary$month),
            x1 = max(tat_summary$month),
            y0 = 0.80,
            y1 = 0.80,
            line = list(dash = "dash", color = "black")
          ))
        } else {
          list()
        }
      ) %>%
      brand_title("Lead Turnaround ≤ 48h") %>%
      plot_brand()
  })

  output$casings_combo <- renderPlotly({
    d <- incidents_f()
    if (nrow(d) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No incidents data available") %>%
          plot_brand()
      )
    }

    casings_summary <- d %>%
      mutate(
        investigative = event_type %in%
          c("Shots Fired", "Non-Fatal Shooting", "Homicide"),
        mmonth = floor_date(month, "month")
      ) %>%
      group_by(mmonth) %>%
      summarise(
        casings_collected = sum(casings_n, na.rm = TRUE),
        scenes_with_casings = sum(casings_n > 0, na.rm = TRUE),
        investigative_scenes = sum(investigative, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(
        scene_recovery_rate = if_else(
          investigative_scenes > 0,
          scenes_with_casings / investigative_scenes,
          NA_real_
        )
      ) %>%
      rename(month = mmonth) %>%
      arrange(month)

    plot_ly() %>%
      add_bars(
        data = casings_summary,
        x = ~month,
        y = ~casings_collected,
        name = "Casings",
        text = ~casings_collected,
        textposition = "outside",
        hovertemplate = "%{x|%Y-%m}: %{y} casings<extra></extra>"
      ) %>%
      add_lines(
        data = casings_summary,
        x = ~month,
        y = ~scene_recovery_rate,
        name = "Recovery rate",
        yaxis = "y2",
        mode = "lines+markers",
        hovertemplate = "%{x|%Y-%m}: %{y:.0%}<extra></extra>"
      ) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Casings", rangemode = "tozero"),
        yaxis2 = list(
          title = "% scenes",
          overlaying = "y",
          side = "right",
          tickformat = ".0%",
          range = c(0, 1),
          automargin = TRUE
        ),
        legend = list(orientation = "h", x = 0.1, y = -0.2),
        margin = list(t = 50, b = 40, r = 90)
      ) %>%
      brand_title("Casings Collected & Scene Recovery Rate") %>%
      plot_brand()
  })

  # ---- Map Outputs ----
  output$incidents_map <- renderLeaflet({
    center_lon <- if (nrow(incidents_view) > 0) {
      mean(incidents_view$lon, na.rm = TRUE)
    } else {
      -84.5
    }

    center_lat <- if (nrow(incidents_view) > 0) {
      mean(incidents_view$lat, na.rm = TRUE)
    } else {
      39.1
    }

    leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(
        lng = center_lon,
        lat = center_lat,
        zoom = config$map$default_zoom
      )
  })

  draw_sectors <- function(show = TRUE) {
    proxy <- leafletProxy("incidents_map") %>% clearGroup("sectors")
    if (!show || nrow(sector_polys) == 0) {
      return(invisible(NULL))
    }

    tryCatch(
      {
        sp <- split(sector_polys, sector_polys$sector)
        for (s in names(sp)) {
          proxy <- proxy %>%
            addPolylines(
              data = sp[[s]],
              lng = ~lon,
              lat = ~lat,
              color = "black",
              weight = 3,
              dashArray = "6,6",
              group = "sectors"
            )
        }

        if (nrow(sector_labels) > 0) {
          proxy <- proxy %>%
            addLabelOnlyMarkers(
              data = sector_labels,
              lng = ~lon,
              lat = ~lat,
              label = ~sector,
              group = "sectors",
              labelOptions = labelOptions(
                noHide = TRUE,
                textOnly = TRUE,
                direction = "center",
                style = list(
                  "color" = "black",
                  "font-weight" = "bold",
                  "font-size" = "14px",
                  "text-shadow" = "1px 1px #ffffff"
                )
              )
            )
        }
      },
      error = function(e) {
        showNotification("Error drawing sectors", type = "warning")
      }
    )
  }

  observeEvent(
    input$show_sectors,
    {
      draw_sectors(isTRUE(input$show_sectors))
    },
    ignoreInit = FALSE
  )

  observe({
    df <- incidents_f()
    show_points <- isTRUE(input$show_points)
    show_heatmap <- isTRUE(input$show_heatmap)

    # Clear all layers first
    proxy <- leafletProxy("incidents_map") %>%
      clearGroup("points") %>%
      clearGroup("heat") %>%
      clearGroup("gun_sel") %>%
      clearControls()

    if (nrow(df) == 0) {
      return()
    }

    tryCatch(
      {
        # Add heatmap if checkbox is checked
        if (show_heatmap) {
          proxy <- proxy %>%
            addHeatmap(
              data = df,
              lng = ~lon,
              lat = ~lat,
              intensity = ~ pmax(1, casings_n),
              blur = config$map$heat_blur,
              max = 0.9,
              radius = config$map$heat_radius,
              group = "heat"
            )
        }

        # Add points if checkbox is checked
        if (show_points) {
          proxy <- proxy %>%
            addCircleMarkers(
              data = df,
              ~lon,
              ~lat,
              radius = ~ pmax(3, scales::rescale(casings_n, c(3, 12))),
              color = ~ pal(event_type),
              stroke = FALSE,
              fillOpacity = 0.7,
              group = "points",
              popup = ~ paste0(
                "<b>Incident:</b> ",
                incident_id,
                "<br><b>When:</b> ",
                occurred_dt,
                "<br><b>Type:</b> ",
                event_type,
                "<br><b>Beat/Sector:</b> ",
                beat,
                " / ",
                sector,
                "<br><b>Casings:</b> ",
                casings_n
              )
            ) %>%
            addLegend(
              "topright",
              pal = pal,
              values = sort(unique(df$event_type)),
              title = "Incident type",
              opacity = 0.8
            )
        }
      },
      error = function(e) {
        showNotification("Error updating map", type = "warning")
      }
    )
  })

  output$incidents_tbl <- renderDT({
    dat <- incidents_f()
    if (nrow(dat) == 0) {
      return(datatable(data.frame(Message = "No data available")))
    }

    display_data <- dat %>%
      arrange(desc(occurred_dt)) %>%
      select(incident_id, occurred_dt, event_type, beat, sector, casings_n)

    datatable(
      display_data,
      selection = "multiple",
      rownames = FALSE,
      options = list(
        paging = FALSE,
        scrollY = config$ui$table_height,
        scrollCollapse = TRUE,
        order = list(list(1, "desc")),
        deferRender = TRUE,
        dom = "ft"
      ),
      filter = "none"
    )
  })

  observeEvent(input$incidents_tbl_rows_selected, {
    rows <- input$incidents_tbl_rows_selected
    df <- incidents_f()
    if (length(rows) && nrow(df) >= max(rows)) {
      tryCatch(
        {
          sel <- df[rows, ]
          if (nrow(sel) > 0 && all(c("lon", "lat") %in% names(sel))) {
            leafletProxy("incidents_map") %>%
              fitBounds(min(sel$lon), min(sel$lat), max(sel$lon), max(sel$lat))
          }
        },
        error = function(e) {
          showNotification(
            "Error zooming to selected incidents",
            type = "warning"
          )
        }
      )
    }
  })

  # ---- Sankey Network ----
  output$sankey <- renderSankeyNetwork({
    ed <- edges_slim()
    if (nrow(ed) == 0) {
      return(NULL)
    }

    tryCatch(
      {
        edges <- ed %>%
          transmute(
            src = paste0("Gun:", firearm_id),
            tgt = paste0("Incident:", incident_id),
            value = 1L
          )

        nodes <- tibble::tibble(name = unique(c(edges$src, edges$tgt))) %>%
          mutate(id = row_number() - 1L)

        links <- edges %>%
          left_join(nodes, by = c("src" = "name")) %>%
          rename(source = id) %>%
          left_join(nodes, by = c("tgt" = "name")) %>%
          rename(target = id) %>%
          transmute(source, target, value)

        sankeyNetwork(
          Links = as.data.frame(links),
          Nodes = as.data.frame(nodes),
          Source = "source",
          Target = "target",
          Value = "value",
          NodeID = "name",
          fontSize = 12,
          nodeWidth = 28,
          sinksRight = FALSE
        )
      },
      error = function(e) {
        showNotification("Error creating network diagram", type = "error")
        NULL
      }
    )
  })

  output$gun_selected_label <- renderUI({
    g <- selected_gun()
    if (is.null(g)) {
      tags$small(em("No gun selected."))
    } else {
      tags$small(strong(sprintf("Selected: %s", g)))
    }
  })

  output$links_title <- renderUI({
    g <- selected_gun()
    if (is.null(g)) {
      HTML("<span>Top Gun ↔ Incident links (Confirmed Hits; Simplified)</span>")
    } else {
      HTML(sprintf("<span>Links for <b>%s</b></span>", g))
    }
  })

  output$links_tbl <- renderDT({
    ed <- edges_slim()
    if (nrow(ed) == 0) {
      return(datatable(data.frame(Message = "No linkage data available")))
    }

    gid <- selected_gun_id()
    if (!is.null(gid)) {
      ed <- ed %>% filter(firearm_id == gid)
    }

    if (nrow(ed) == 0) {
      return(datatable(data.frame(Message = "No links for selected gun")))
    }

    edx <- ed %>%
      left_join(
        incidents_view %>%
          select(incident_id, occurred_dt, event_type, beat, sector),
        by = "incident_id"
      ) %>%
      arrange(desc(occurred_dt)) %>%
      select(firearm_id, incident_id, occurred_dt, event_type, beat, sector)

    datatable(
      edx,
      rownames = FALSE,
      options = list(
        paging = FALSE,
        scrollY = 300,
        scrollCollapse = TRUE,
        order = list(list(2, "desc")),
        deferRender = TRUE,
        dom = "ft"
      )
    )
  })

  output$links_over_time <- renderPlotly({
    # Always use edges_base() regardless of gun selection
    ef <- edges_base()
    if (nrow(ef) == 0) {
      return(
        plot_ly() %>%
          layout(title = "No linkage data available") %>%
          plot_brand()
      )
    }

    monthly <- ef %>%
      count(month, name = "links") %>%
      left_join(
        ef %>%
          group_by(month) %>%
          summarise(guns = n_distinct(firearm_id), .groups = "drop"),
        by = "month"
      ) %>%
      mutate(avg_inc_per_gun = ifelse(guns > 0, links / guns, NA_real_)) %>%
      arrange(month)

    plot_ly() %>%
      add_bars(
        data = monthly,
        x = ~month,
        y = ~links,
        name = "Links",
        marker = list(color = CGIC$blue)
      ) %>%
      add_lines(
        data = monthly,
        x = ~month,
        y = ~avg_inc_per_gun,
        name = "Avg incidents / gun",
        yaxis = "y2",
        line = list(color = CGIC$gold, width = 3)
      ) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Links", rangemode = "tozero"),
        yaxis2 = list(
          title = "Avg incidents / gun",
          overlaying = "y",
          side = "right"
        ),
        legend = list(orientation = "h", x = 0.1, y = -0.2),
        margin = list(r = 80, b = 50)
      ) %>%
      brand_title("Linkage Volume & Avg Incidents per Gun (Monthly)") %>%
      plot_brand()
  })

  # Recent vs Historical Activity
  output$hits_by_gun <- renderPlotly({
    ef <- edges_base()
    if (nrow(ef) == 0) {
      return(plot_ly() %>% layout(title = "No data available") %>% plot_brand())
    }

    gid <- selected_gun_id()

    if (!is.null(gid)) {
      # For individual gun: show monthly activity pattern
      gun_monthly <- ef %>%
        filter(firearm_id == gid) %>%
        left_join(
          incidents_view %>% select(incident_id, occurred_dt),
          by = "incident_id"
        ) %>%
        mutate(month = floor_date(occurred_dt, "month")) %>%
        count(month, name = "hits") %>%
        arrange(month)

      if (nrow(gun_monthly) == 0) {
        return(
          plot_ly() %>%
            layout(title = paste("No data for", gid)) %>%
            plot_brand()
        )
      }

      plot_ly(
        gun_monthly,
        x = ~month,
        y = ~hits,
        type = "bar",
        marker = list(color = CGIC$blue)
      ) %>%
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Monthly Hits", rangemode = "tozero")
        ) %>%
        brand_title(sprintf("Activity Pattern — %s", gid)) %>%
        plot_brand()
    } else {
      # For all guns: show recent vs historical activity
      recent_cutoff <- max(incidents_view$occurred_dt, na.rm = TRUE) - days(90)

      gun_activity <- ef %>%
        left_join(
          incidents_view %>% select(incident_id, occurred_dt),
          by = "incident_id"
        ) %>%
        group_by(firearm_id) %>%
        summarise(
          recent_hits = sum(occurred_dt >= recent_cutoff, na.rm = TRUE),
          historical_hits = sum(occurred_dt < recent_cutoff, na.rm = TRUE),
          total_hits = n(),
          .groups = "drop"
        ) %>%
        filter(total_hits >= 2) %>%
        arrange(desc(recent_hits)) %>%
        slice_head(n = 6)

      plot_ly() %>%
        add_bars(
          data = gun_activity,
          x = ~firearm_id,
          y = ~historical_hits,
          name = "Historical (>90 days)",
          marker = list(color = CGIC$dkgrey)
        ) %>%
        add_bars(
          data = gun_activity,
          x = ~firearm_id,
          y = ~recent_hits,
          name = "Recent (≤90 days)",
          marker = list(color = CGIC$gold)
        ) %>%
        layout(
          barmode = "stack",
          xaxis = list(title = "Gun ID"),
          yaxis = list(title = "Hits", rangemode = "tozero")
        ) %>%
        brand_title("Recent vs Historical Activity (Top 6 Guns)") %>%
        plot_brand()
    }
  })
}
# ---- Launch Application ----
shinyApp(ui, server)
