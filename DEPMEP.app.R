# DEPMEP.app
# MassDEP Maximum Extent Practicable viewer Shiny app
# See https://github.com/bwcompton/DEPMEP
# Before initial deployment on shinyapps.io, need to restart R and:
#    library(remotes); install_github('bwcompton/readMVT'); install_github('bwcompton/leaflet.lagniappe')
# B. Compton, 13-21 Jul 2023 (from app_test_further3.R)



library(shiny)
library(leaflet)
library(readMVT)
library(htmltools)
library(sf)
library(leaflet.lagniappe)

source('modalHelp.R')
source('format.culverts.R')
source('format.streams.R')
source('fmt.hq.R')


home <- c(-71.6995, 42.1349)  # center of Massachusetts
zoom <- 8                     # starting zoom level (shows all of Massachusetts)

data.zoom <- 14               # all MVT tiles are read at this zoom level to simplify caching
trigger <- 14                 # show vector data when zoomed in this far or more
zoom.levels = 14:22           # show vector data at these zoom levels

howto <- includeMarkdown('inst/howto.md')                   # How to use this tool
aboutMEP <- includeMarkdown('inst/aboutMEP.md')             # Intro to MEP
crossings <- includeMarkdown('inst/crossings.md')           # Crossing standards
source_data <- includeMarkdown('inst/sourcedata.md')        # Links to source data
beta <- includeMarkdown('inst/beta.md')                     # Beta test notice

xml <- read.XML('https://umassdsl.webgis1.com/geoserver')   # get capabilties of our GeoServer
streamlines <- layer.info(xml, 'DEPMEP:streams')            # get info for stream linework
culverts <- layer.info(xml, 'testbed:CL_crossings7')        # get info for crossing points


# User interface ---------------------
ui <- fluidPage(
   titlePanel('MassDEP culvert and bridge upgrade assessment tool'),
   tags$head(includeScript('inst/matomo.js')),              # add Matomo tracking JS
   fluidRow(
      column(2,
             br(actionLink('howto', label = 'About this site')),
             br(actionLink('aboutMEP', label = 'About MEP guidance')),
             br(actionLink('crossings', label = 'Massachusetts River and Stream Crossing Standards')),
            # br(HTML('<a href="https://umassdsl.org/404" target="_blank" rel="noopener noreferrer">MEP guidance document</a>')),
            # br(HTML('<a href="https://www.mass.gov/doc/massachusetts-river-and-stream-crossing-standards" target="_blank" rel="noopener noreferrer">Massachusetts River and Stream Crossing Standards</a>')),
             br(HTML('<a href="https://www.mass.gov/regulations/310-CMR-1000-wetlands-protection-act-regulations" target="_blank" rel="noopener noreferrer">Massachusetts Wetlands Protection Act</a>')),
             br(actionLink('sourcedata', label = 'Data sources')),
             br(actionLink('beta', label = 'Beta test')),
             br(helpText(HTML('<p style="color: red">FAKE DATA FOR TESTING!</p>'))),
             tags$img(height = 120, src = 'logos.png', style = 'position: absolute;top: 65vh;display: block;float: left;')
      ),
      column(10,
             leafletOutput('map', height = '80vh')
      ))
)


# Server -----------------------------
server <- function(input, output, session) {

   observeEvent(input$howto, {
      modalHelp(howto, 'About this site')})
   observeEvent(input$aboutMEP, {
      modalHelp(aboutMEP, title = 'About MEP guidance')})
   observeEvent(input$crossings, {
      modalHelp(crossings, title = 'Massachusetts River and Stream Crossing Standards')})
   observeEvent(input$sourcedata, {
      modalHelp(source_data, title = 'Data sources')})
   observeEvent(input$beta, {
      modalHelp(beta, title = 'Beta test')})

   output$map <- renderLeaflet({
      leaflet() |>
         addTiles(urlTemplate = '', attribution =
                     '<a href="https://www.mass.gov/orgs/massachusetts-department-of-environmental-protection"
                  target="_blank" rel="noopener noreferrer">Mass DEP | </a><a href="https://umassdsl.org"
                  target="_blank" rel="noopener noreferrer">UMass DSL</a>') |>
         addProviderTiles(providers$Esri.WorldStreetMap) |>
         setView(lng = home[1], lat = home[2], zoom = zoom) |>
         osmGeocoder(email = 'bcompton@umass.edu') |>
         addScaleBar(position = 'bottomright') |>
         addFullscreen()
   })

   observe({
      if(isTRUE(input$map_zoom >= trigger)) {
         nw <- get.tile(data.zoom, input$map_bounds$north, input$map_bounds$west)   # corners of viewport
         se <- get.tile(data.zoom, input$map_bounds$south, input$map_bounds$east)
         m <- leafletProxy('map', session)

         x <- read.viewport.tiles(streamlines, nw, se, data.zoom, session$userData[[streamlines$layer]])  # get streams
         session$userData[[streamlines$layer]] <- x$drawn
         if(!is.null(x$tiles)) {
            p <- format.streams(x$tiles)
            m <- addPolylines(m, data = x$tiles, group = 'vector', opacity = 1, color = 'cornflowerblue', weight = 3,
                              popup = p)
         }

         x <- read.viewport.tiles(culverts, nw, se, data.zoom, session$userData[[culverts$layer]])        # get culverts
         session$userData[[culverts$layer]] <- x$drawn
         if(!is.null(x$tiles)) {
          p <- format.culverts(x$tiles)
            m <- addCircleMarkers(m, data = x$tiles, group = 'vector', opacity = 1, color = 'orange', radius = 4,
                                  popup = p)
         }

         return(groupOptions(m, 'vector', zoomLevels = zoom.levels))
      }
   })
}


shinyApp(ui, server)
