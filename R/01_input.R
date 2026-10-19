# =============================================================================
# 01_input.R  -  Data ophalen uit StatLine via de OData-API (cbsodataR)
# Geen externe databestanden: alles komt rechtstreeks uit tabel 83131NED.
# =============================================================================

#' Haal maand- en jaarcijfers van de CPI op voor een set productcodes
#'
#' @param tabel     StatLine-tabelnummer, bijv. "83131NED"
#' @param producten COICOP-codes zoals ze in StatLine staan, bijv. "011530"
#' @param startjaar eerste jaar dat wordt bewaard
#' @return list met $maand en $jaar (nette data frames) en $meta
haal_cpi_op <- function(tabel, producten, startjaar) {

  meta <- cbs_get_meta(tabel)

  # 1. Productcodes vertalen naar StatLine-keys.
  #    De titels beginnen met de COICOP-code ("011530 Olijfolie"), de keys niet
  #    altijd. Daarom zoeken we op titel; zo werkt het script ook als CBS de
  #    keys ooit anders noemt.
  cat_meta   <- meta$Bestedingscategorieen
  cat_codes  <- substr(trimws(cat_meta$Title), 1, 6)
  gekozen    <- cat_meta[cat_codes %in% producten, ]
  niet_gevonden <- setdiff(producten, substr(trimws(gekozen$Title), 1, 6))
  if (length(niet_gevonden) > 0) {
    stop("Productcode(s) niet gevonden in ", tabel, ": ",
         paste(niet_gevonden, collapse = ", "), call. = FALSE)
  }

  # 2. Kolom met de CPI-index zelf opzoeken (niet de mutaties, niet 'afgeleid').
  dp      <- meta$DataProperties
  cpi_key <- dp$Key[trimws(dp$Title) == "CPI" & dp$Type == "Topic"]
  if (length(cpi_key) != 1) {
    stop("Kolom 'CPI' niet eenduidig gevonden. Beschikbare onderwerpen: ",
         paste(dp$Title[dp$Type == "Topic"], collapse = " | "), call. = FALSE)
  }

  # 3. Data ophalen: alleen de gekozen producten en de CPI-kolom.
  ruw <- cbs_get_data(tabel,
                      Bestedingscategorieen = gekozen$Key,
                      select = c("Bestedingscategorieen", "Perioden", cpi_key))

  # 4. Opschonen naar één net formaat.
  #    Periodecodes: "2019MM01" = maand, "2019JJ00" = jaar.
  net <- ruw %>%
    transmute(
      product_key  = trimws(Bestedingscategorieen),
      periode_code = trimws(Perioden),
      cpi          = as.numeric(.data[[cpi_key]])
    ) %>%
    left_join(tibble(product_key  = trimws(gekozen$Key),
                     product_code = substr(trimws(gekozen$Title), 1, 6),
                     product_naam = trimws(substring(trimws(gekozen$Title), 8))),
              by = "product_key") %>%
    mutate(jaar = as.integer(substr(periode_code, 1, 4))) %>%
    filter(jaar >= startjaar)

  maand <- net %>%
    filter(grepl("MM", periode_code)) %>%
    mutate(maand    = as.integer(substr(periode_code, 7, 8)),
           kwartaal = (maand - 1) %/% 3 + 1,
           datum    = as.Date(sprintf("%d-%02d-01", jaar, maand))) %>%
    arrange(product_code, datum)

  jaar <- net %>%
    filter(grepl("JJ", periode_code)) %>%
    arrange(product_code, jaar)

  if (nrow(maand) == 0) stop("Geen maandcijfers opgehaald.", call. = FALSE)
  if (anyNA(maand$cpi)) warning("Er ontbreken CPI-waarden in de maanddata.")

  message("Input: ", nrow(maand), " maandcijfers opgehaald voor ",
          length(producten), " producten (", min(maand$jaar), "-",
          max(maand$jaar), ").")

  list(maand = maand, jaar = jaar, meta = meta)
}
