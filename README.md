# CGIC Demo Dashboard 

A Crime Gun Intelligence Center (CGIC) demo dashboard for analyzing gun-related incidents, NIBIN data, and firearms linkages. This interactive dashboard provides law enforcement agencies with tools to track shooting incidents, monitor NIBIN leads and hits, and analyze firearm linkage patterns.

## Features

- **Interactive Incident Mapping**: Toggle between point and heatmap visualizations with sector overlays
- **NIBIN Analytics**: Track leads, confirmed hits, and turnaround times with KPI monitoring
- **Gun Linkage Analysis**: Sankey diagrams showing gun-to-incident connections with filtering capabilities
- **Temporal Analysis**: Trend analysis for incidents, clearance rates, and gun activity patterns
- **Geographic Filtering**: Filter by beats, event types, and date ranges
- **Clearance Tracking**: Monitor case clearance rates and time-to-clearance metrics

## Data Structure

The dashboard expects CSV files in the `data/poc/` directory:

- `table_incidents.csv` - Shooting incident records (homicides, non-fatal shootings, shots fired)
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
