# =============================================================================
# 02_throughput.R  -  Berekeningen en controles
# =============================================================================

#' Kwartaal-CPI = gemiddelde van de drie maandindexcijfers
maak_kwartaalcijfers <- function(maand) {
  maand %>%
    group_by(product_code, product_naam, jaar, kwartaal) %>%
    summarise(cpi_kwartaal = mean(cpi),
              n_maanden    = n(),
              .groups      = "drop") %>%
    mutate(verslagperiode = paste0(jaar, "KW", kwartaal),
           volledig       = n_maanden == 3) %>%
    arrange(product_code, jaar, kwartaal)
}

#' Vorig kwartaal bepalen, bijv. "2025KW1" -> "2024KW4"
vorig_kwartaal <- function(verslagperiode) {
  jaar <- as.integer(substr(verslagperiode, 1, 4))
  kw   <- as.integer(substr(verslagperiode, 7, 7))
  ifelse(kw == 1, paste0(jaar - 1, "KW4"), paste0(jaar, "KW", kw - 1))
}

#' Kwartaalmutatie (%) van de CPI voor één verslagperiode
#'
#' @param periode  de verslagperiode, een kwartaal in de vorm "JJJJKWn", bijv. "2025KW3"
#' @param kwartaal uitkomst van maak_kwartaalcijfers()
#' @return één rij per product met CPI van het kwartaal, het vorige kwartaal
#'         en de procentuele verandering
bereken_kwartaalmutatie <- function(periode, kwartaal) {

  if (!grepl("^[0-9]{4}KW[1-4]$", periode)) {
    stop("Verslagperiode moet de vorm 'JJJJKWn' hebben, bijv. '2025KW3'.",
         call. = FALSE)
  }
  vorige <- vorig_kwartaal(periode)

  huidig <- kwartaal %>% filter(verslagperiode == periode, volledig)
  vorig  <- kwartaal %>% filter(verslagperiode == vorige, volledig) %>%
    select(product_code, cpi_vorig = cpi_kwartaal)

  if (nrow(huidig) == 0 || nrow(vorig) == 0) {
    warning("Geen volledige data voor ", periode, " en/of ", vorige,
            "; mutatie niet berekend.", call. = FALSE)
    return(NULL)
  }

  huidig %>%
    inner_join(vorig, by = "product_code") %>%
    transmute(product_code, product_naam, verslagperiode,
              vorige_periode      = vorige,
              cpi_kwartaal, cpi_vorig,
              kwartaalmutatie_pct = (cpi_kwartaal / cpi_vorig - 1) * 100)
}

#' Dezelfde functie toepassen op alle kwartalen waarvoor een vorig kwartaal is
bereken_alle_mutaties <- function(kwartaal) {
  periodes <- unique(kwartaal$verslagperiode[kwartaal$volledig])
  periodes <- periodes[vorig_kwartaal(periodes) %in% periodes]
  bind_rows(lapply(periodes, bereken_kwartaalmutatie, kwartaal = kwartaal))
}

#' Controle: het gemiddelde van 12 maanden moet gelijk zijn aan het door CBS
#' gepubliceerde jaarcijfer (op afronding na). Zo toetsen we dat de
#' middelingsmethode klopt met die van CBS zelf.
controleer_jaargemiddelden <- function(maand, jaar, tolerantie = 0.01) {
  if (nrow(jaar) == 0) {
    message("Controle overgeslagen: geen jaarcijfers beschikbaar.")
    return(invisible(NULL))
  }
  vergelijk <- maand %>%
    group_by(product_code, jaar) %>%
    summarise(eigen = mean(cpi), n = n(), .groups = "drop") %>%
    filter(n == 12) %>%
    inner_join(jaar %>% select(product_code, jaar, gepubliceerd = cpi),
               by = c("product_code", "jaar")) %>%
    mutate(verschil = abs(eigen - gepubliceerd))

  afwijkend <- filter(vergelijk, verschil > tolerantie)
  if (nrow(afwijkend) > 0) {
    warning("Jaargemiddelde wijkt af van StatLine bij: ",
            paste(afwijkend$product_code, afwijkend$jaar, collapse = ", "),
            call. = FALSE)
  } else {
    message("Controle: jaargemiddelden komen overeen met StatLine (max. verschil ",
            format(max(vergelijk$verschil), digits = 2), ").")
  }
  invisible(vergelijk)
}
