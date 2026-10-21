# Tests voor de rekenfuncties. Draaien vanuit de hoofdmap:
#   source("tests/test_throughput.R")
suppressPackageStartupMessages(library(dplyr))
source("R/02_throughput.R")

# 1. Jaargrens: KW1 wordt vergeleken met KW4 van het jaar ervoor
stopifnot(vorig_kwartaal("2025KW1") == "2024KW4",
          vorig_kwartaal("2025KW3") == "2025KW2")

# 2. Kwartaalgemiddelde en kwartaalmutatie op een klein, bekend voorbeeld
maand <- tibble(product_code = "X", product_naam = "Test", jaar = 2025L,
                kwartaal = rep(1:2, each = 3),
                cpi = c(100, 101, 102, 103, 104, 105))
kw <- maak_kwartaalcijfers(maand)
stopifnot(isTRUE(all.equal(kw$cpi_kwartaal, c(101, 104))))
mut <- bereken_kwartaalmutatie("2025KW2", kw)
stopifnot(abs(mut$kwartaalmutatie_pct - (104 / 101 - 1) * 100) < 1e-9)

# 3. Een kwartaal met minder dan drie maanden telt niet mee
kw_onvolledig <- maak_kwartaalcijfers(maand[-6, ])
stopifnot(!kw_onvolledig$volledig[kw_onvolledig$kwartaal == 2])

# 4. Een verkeerd geformatteerde periode geeft een foutmelding
stopifnot(inherits(try(bereken_kwartaalmutatie("2025Q2", kw), silent = TRUE),
                   "try-error"))

message("Alle tests geslaagd.")
