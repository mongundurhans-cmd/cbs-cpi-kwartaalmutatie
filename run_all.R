# run_all.R  -  Kwartaalmutaties CPI per product (CBS StatLine, tabel 83131NED)
# hele proces: input -> throughput -> output.

# ---- 1. Instellingen (alleen hier aanpassen) --------------------------------
instellingen <- list(
  tabel          = "83131NED",                # CPI, 2015 = 100
  producten      = c("011530",                # Olijfolie
                     "091190"),               # Hoofdtelefoons, e-readers e.d.
  startjaar      = 2019,                      # eerste jaar 
  verslagperiode = "2025KW4",                 # kwartaal dat apart wordt gerapporteerd
  map_output     = "output",
  database       = "output/cpi_kwartaal.sqlite"
)

# ---- 2. Packages -------------------------------------------------------------
benodigd <- c("cbsodataR", "dplyr", "ggplot2", "DBI", "RSQLite")
ontbreekt <- benodigd[!vapply(benodigd, requireNamespace, logical(1), quietly = TRUE)]
if (length(ontbreekt) > 0) {
  stop("Installeer eerst: install.packages(c(\"",
       paste(ontbreekt, collapse = "\", \""), "\"))", call. = FALSE)
}
suppressPackageStartupMessages({
  library(cbsodataR)
  library(dplyr)
  library(ggplot2)
  library(DBI)
  library(RSQLite)
})

# ---- 3. Functies laden -------------------------------------------------------
source("R/01_input.R")
source("R/02_throughput.R")
source("R/03_output.R")

# ---- 4. Input: data ophalen uit StatLine -------------------------------------
cpi <- haal_cpi_op(instellingen$tabel, instellingen$producten, instellingen$startjaar)

# ---- 5. Throughput: kwartaalcijfers, mutaties en controles -------------------
kwartaal  <- maak_kwartaalcijfers(cpi$maand)
controleer_jaargemiddelden(cpi$maand, cpi$jaar)
mutaties  <- bereken_alle_mutaties(kwartaal)
verslag   <- bereken_kwartaalmutatie(instellingen$verslagperiode, kwartaal)

# ---- 6. Output: grafieken en SQLite-database ---------------------------------
dir.create(instellingen$map_output, showWarnings = FALSE)
maak_grafieken(cpi$maand, kwartaal, mutaties, instellingen$map_output)
schrijf_naar_sqlite(cpi$maand, kwartaal, mutaties, instellingen)

message("\nKwartaalmutatie CPI, verslagperiode ", instellingen$verslagperiode, ":")
print(as.data.frame(verslag) %>%
        transmute(product_naam,
                  cpi_kwartaal  = round(cpi_kwartaal, 2),
                  cpi_vorig     = round(cpi_vorig, 2),
                  kwartaalmutatie_pct = round(kwartaalmutatie_pct, 1)),
      row.names = FALSE)
message("\nKlaar. Resultaten staan in de map '", instellingen$map_output, "'.")
