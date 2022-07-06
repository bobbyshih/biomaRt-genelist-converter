# Load packages
library(shiny)
library(dplyr)
library(data.table)
library(writexl)
library(biomaRt)
library(shinyjs)

# Define UI for application that draws a histogram ----
ui <- navbarPage("biomaRt Gene List Converter",
    
    shinyjs::useShinyjs(),
                 
      # Side Bar Layout with input and output definition ----
      sidebarLayout(
        
        # Sidebar Panel for file input ----
        sidebarPanel(
        
        # Upload files containing a list of genes
        helpText("Convert a list of genes using one identifier to another and/or functionally annotate a list of genes using biomaRT"),
        
        helpText("Please note that it may take 1 - 2 minutes for results to appear after submitting"),
        
        helpText("If the output result contains only NA's this likely means  the wrong input identifier was selected"),
        # Horizontal line ----
        tags$hr(),
        
        helpText("Please input a file containing ONLY a single list as a .csv file with one gene per row"),
        fileInput("file1", "Choose Input File",
                  multiple = FALSE,
                  accept = c(".csv")
                  ),
        
        # Input: Checkbox if file has header ----
        checkboxInput("header", "Header", FALSE),
        
        
        # Input: Select species ----
        radioButtons("species", "Select Species",
                     choices = c('Human' = "hsapiens_gene_ensembl",
                                 'Mouse' = "mmusculus_gene_ensembl"),
                     selected = "hsapiens_gene_ensembl"),
        
        
        # Input: Select input gene identifiers ----
        selectInput("input_identifier", "Select Input Identifier",
                    c("Official Gene Name" = "external_gene_name",
                      "Ensembl Gene ID" = "ensembl_gene_id",
                      "Ensemble Gene ID Version" = "ensembl_gene_id_version",
                      "EntrezGene transcript name ID" = "entrezgene_trans_name",
                      "HGNC ID" = "hgnc_id",
                      "HGNC Symbol" = "hgnc_symbol",
                      "WikiGene name" = "wikigene_name",
                      "GO term name" = "name_1006"
                      )),
        
        # Horizontal line ----
        tags$hr(),
        
        # Output: Select output gene identifiers ----
        selectInput("output_identifier", "Select Output Identifier",
                    c("Official Gene Name" = "external_gene_name",
                      "Ensembl Gene ID" = "ensembl_gene_id",
                      "Ensemble Gene ID Version" = "ensembl_gene_id_version",
                      "EntrezGene transcript name ID" = "entrezgene_trans_name",
                      "HGNC ID" = "hgnc_id",
                      "HGNC Symbol" = "hgnc_symbol",
                      "WikiGene name" = "wikigene_name",
                      "GO term name" = "name_1006"
                    )),
        
        # Output: Select gene description
        selectInput("output_description", "Select Gene Description",
                    c("NCBI gene description" = 'entrezgene_description',
                      "WikiGene description" = 'wikigene_description',
                      "Phenotype description" = 'phenotype_description',
                      "GOSlim GOA Description" = 'goslim_goa_description',
                      "MIM gene description" = 'mim_gene_description')
                    ),
        
        # Horizontal line ----
        tags$hr(),
        
        # Run button ----
        
        actionButton("submit", label = "Submit"),
        
        # Save Data
        # selectInput("file_format", label = h4("Save data as"), choices = c("csv", "txt", "xlsx", "xls"), selected = "csv"),
        downloadButton('downloadData', 'Download Data as .csv')
      ),
      
      # Main panel for displaying outputs ----
      mainPanel(
        
        # Output: Data file
        tableOutput("contents")
        
      )
))


# Define server logic
server <- function(input, output) {
    
    shinyjs::disable("downloadData")
    
    observeEvent( input$submit, {
      
      req(input$file1)
      
      if (input$header == FALSE) {
      
        genelist_df <- read.csv(input$file1$datapath,
                                header = FALSE)
        
        names(genelist_df)[1] <- 'Input'
        
      } else {
        
        genelist_df <- read.csv(input$file1$datapath,
                                header = TRUE)
        names(genelist_df)[1] <- 'Input'
      }
      
      if (input$species == "hsapiens_gene_ensembl") {
      
        ensembl <- readRDS("Data/ensembl_human.rds")
      
      } else {
      
        ensembl <- readRDS("Data/ensembl_mouse.rds")
      }
      
      ensembl_id_mgi <-  getBM(attributes=c(input$input_identifier, input$output_identifier, input$output_description), 
                               filters = input$input_identifier, 
                               values = genelist_df$Input, 
                               mart = ensembl)
      
      # Remove duplicate entries
      ensembl_id_mgi <- distinct(ensembl_id_mgi, ensembl_id_mgi[,1], .keep_all = TRUE)
      
      # Add new identifiers to genelist_df
      
      genelist_df$output_identifier <- ensembl_id_mgi[,2][match(genelist_df$Input, ensembl_id_mgi[,1])]
      names(genelist_df)[2] <- input$output_identifier
      
      # Add descriptions to genelist_df
      
      genelist_df$output_description <- ensembl_id_mgi[,3][match(genelist_df$Input, ensembl_id_mgi[,1])]
      names(genelist_df)[3] <- input$output_description
      
      output$contents <- renderTable({
      return(head(genelist_df, n = 40))
      })
      
      shinyjs::enable("downloadData")
      
      output$downloadData <- downloadHandler(
        filename = function() {paste(substring(basename(input$file1$name), 1, nchar(basename(input$file1$name)) - 4), "-biomaRt-", Sys.Date(), ".csv", sep = '')},
        content = function(file) {write.csv(genelist_df, file, row.names = FALSE)}
      )
      
    })
    
  }

# Run the application 
shinyApp(ui = ui, server = server)