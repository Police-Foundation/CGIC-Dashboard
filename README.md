# CGIC Demo Dashboard

A Crime Gun Intelligence Center (CGIC) demo dashboard for analyzing gun-related incidents, NIBIN data, and firearms linkages. This interactive dashboard provides law enforcement agencies with tools to track shooting incidents, monitor NIBIN leads and hits, and analyze firearm linkage patterns.

## Features

- **Interactive Incident Mapping**: Toggle between point, heatmap, beat boundary, and sector overlays
- **NIBIN Analytics**: Track leads, hits, and turnaround times with KPI monitoring
- **Gun Linkage Analysis**: Sankey diagrams showing gun-to-incident connections with filtering capabilities; click a row in the links table to filter the Sankey to that incident's network
- **Temporal Analysis**: Trend analysis for incidents, clearance rates, and gun activity patterns
- **Global Filters**: Sidebar with incident type checkboxes, beat selector, date range, and NIBIN leads filter — persists across all tabs
- **Smart Sidebar**: Automatically hidden on the Instructions tab and open on data tabs; manually collapsible on any tab
- **Clearance Tracking**: Monitor case clearance rates and time-to-clearance metrics
- **Full Incident Type Coverage**: Supports Shots Fired, Non-Fatal Shooting, Homicide, Accidental, and Justified incident types with distinct colors

## Data Structure

The dashboard expects CSV files in the `data/poc/` directory:

- `table_incidents.csv` - Shooting incident records (homicides, non-fatal shootings, shots fired, accidental, justified)
- `table_leads.csv` - NIBIN correlation lead data with hit confirmations
- `table_acquisitions.csv` - Evidence acquisition records from scenes and test-fires
- `table_lead_incident_links.csv` - Linkage relationships between firearms and incidents

## Demo Data

This repository includes synthetic demonstration data that is not representative of any actual city, locality, or jurisdiction. The data is manufactured for visualization purposes only.

## Installation & Deployment

### Requirements
- R 4.0+
- Required packages: shiny, bslib, DT, leaflet, plotly, networkD3, dplyr, and others (see app.R)

### Local Development
```r
# Install required packages
install.packages(c("shiny", "bslib", "DT", "leaflet", "leaflet.extras",
                   "plotly", "networkD3", "readr", "dplyr", "lubridate",
                   "tidyr", "scales", "htmlwidgets", "stringr", "shinycssloaders"))

# Run the application
shiny::runApp("app.R")
