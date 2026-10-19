# =============================================================================
# 03_output.R  -  Grafieken en opslag in SQLite
# =============================================================================

#' Twee grafieken: indexverloop (maand + kwartaal) en kwartaalmutaties
maak_grafieken <- function(maand, kwartaal, mutaties, map_output) {

  kw_punten <- kwartaal %>%
    filter(volledig) %>%
    mutate(datum = as.Date(sprintf("%d-%02d-15", jaar, (kwartaal - 1) * 3 + 2)))

  # 1. Lijngrafiek: maandindex (dun) en kwartaalgemiddelde (dik)
  g_index <- ggplot() +
    geom_line(data = maand, aes(datum, cpi), colour = "grey60", linewidth = 0.4) +
    geom_line(data = kw_punten, aes(datum, cpi_kwartaal), colour = "#00A1CD",
              linewidth = 1) +
    geom_hline(yintercept = 100, linetype = "dashed", colour = "grey40") +
    facet_wrap(~ product_naam, ncol = 2) +
    labs(title    = "Consumentenprijsindex per product (2015 = 100)",
         subtitle = "Grijs: maandcijfer, blauw: kwartaalgemiddelde",
         x = NULL, y = "CPI (2015 = 100)",
         caption  = "Bron: CBS StatLine, tabel 83131NED") +
    theme_minimal(base_size = 11)

  # 2. Staafdiagram: kwartaalmutaties, positief/negatief in eigen kleur
  g_mutatie <- ggplot(mutaties,
                      aes(verslagperiode, kwartaalmutatie_pct,
                          fill = kwartaalmutatie_pct >= 0)) +
    geom_col(width = 0.8) +
    geom_hline(yintercept = 0, colour = "grey30") +
    facet_wrap(~ product_naam, ncol = 1) +
    scale_fill_manual(values = c(`TRUE` = "#E94C0A", `FALSE` = "#00A1CD"),
                      guide = "none") +
    scale_x_discrete(breaks = function(x) x[grepl("KW1$", x)]) +
    labs(title = "Kwartaalmutatie CPI (% t.o.v. vorig kwartaal)",
         x = NULL, y = "%",
         caption = "Bron: CBS StatLine, tabel 83131NED; eigen berekening") +
    theme_minimal(base_size = 11)

  ggsave(file.path(map_output, "cpi_index.png"), g_index,
         width = 10, height = 4.5, dpi = 150, bg = "white")
  ggsave(file.path(map_output, "cpi_kwartaalmutatie.png"), g_mutatie,
         width = 10, height = 6, dpi = 150, bg = "white")
  message("Output: grafieken opgeslagen in '", map_output, "'.")
  invisible(list(index = g_index, mutatie = g_mutatie))
}

#' Resultaten wegschrijven naar SQLite (tabellen worden bij elke run vervangen)
schrijf_naar_sqlite <- function(maand, kwartaal, mutaties, instellingen) {
  con <- dbConnect(RSQLite::SQLite(), instellingen$database)
  on.exit(dbDisconnect(con))

  dbWriteTable(con, "cpi_maand",
               maand %>% mutate(datum = as.character(datum)), overwrite = TRUE)
  dbWriteTable(con, "cpi_kwartaal", kwartaal, overwrite = TRUE)
  dbWriteTable(con, "kwartaalmutatie", mutaties, overwrite = TRUE)
  dbWriteTable(con, "run_info", data.frame(
    tabel      = instellingen$tabel,
    producten  = paste(instellingen$producten, collapse = ","),
    startjaar  = instellingen$startjaar,
    run_tijd   = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    r_versie   = R.version.string
  ), overwrite = TRUE)

  message("Output: ", nrow(mutaties), " kwartaalmutaties opgeslagen in '",
          instellingen$database, "' (tabellen: ",
          paste(dbListTables(con), collapse = ", "), ").")
}
