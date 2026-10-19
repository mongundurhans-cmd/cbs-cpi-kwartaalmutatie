# Kwartaalmutaties CPI per product

Casus 1, data engineer macro-economie (PCO), CBS.

Het script haalt maandcijfers van de consumentenprijsindex (CPI, 2015 = 100) op uit StatLine-tabel **83131NED**. Daarna berekent het per product de kwartaal-CPI en de kwartaalmutatie, maakt het twee grafieken en slaat het de resultaten op in een SQLite-database. Er worden geen externe databestanden (.csv of .xlsx) gebruikt: de data komt rechtstreeks uit de OData-API van CBS.

Gekozen producten:

| COICOP | Product |
|---|---|
| 011530 | Olijfolie |
| 091190 | Hoofdtelefoons, e-readers e.d. |

## Gebruik

1. Installeer R (≥ 4.3) en de packages:
   ```r
   install.packages(c("cbsodataR", "dplyr", "ggplot2", "DBI", "RSQLite"))
   ```
2. Clone deze repository en open de map als RStudio-project (of zet de working directory op de hoofdmap).
3. Run `run_all.R`.

Alle instellingen staan bovenaan `run_all.R`, waaronder de tabel, de productcodes, het startjaar en de verslagperiode. Wil je een ander product of een andere periode? Dan pas je alleen die regels aan. De rest van de code blijft ongewijzigd.

## Structuur

```
├── run_all.R            # startpunt: instellingen + aanroep van alle stappen
├── R/
│   ├── 01_input.R       # INPUT: data ophalen uit StatLine (cbsodataR)
│   ├── 02_throughput.R  # THROUGHPUT: kwartaalcijfers, mutaties, controles
│   └── 03_output.R      # OUTPUT: grafieken en SQLite
└── output/
    ├── cpi_index.png
    ├── cpi_kwartaalmutatie.png
    └── cpi_kwartaal.sqlite
```

Input, throughput en output staan in aparte bestanden en communiceren alleen via data frames. Zo kun je elke stap los testen of vervangen. Een andere bron in `01_input.R` raakt bijvoorbeeld de berekeningen niet.

## Proces

**Input.** `haal_cpi_op()` leest eerst de metadata van de tabel. De productcodes worden via de titels (bijv. "011530 Olijfolie") vertaald naar StatLine-keys, en de kolom met de CPI-index wordt op naam opgezocht. Het script hangt dus niet van hard gecodeerde interne keys af en stopt met een duidelijke foutmelding als een code niet bestaat. Vervolgens worden alleen de benodigde producten en de CPI-kolom opgehaald.

**Throughput.**
- `maak_kwartaalcijfers()`: de kwartaal-CPI is het gemiddelde van de drie maandindexcijfers. Kwartalen met minder dan drie maanden worden gemarkeerd als onvolledig en niet gebruikt.
- `bereken_kwartaalmutatie(verslagperiode, kwartaal)`: de kernfunctie. Neem bijvoorbeeld verslagperiode `"2025KW3"`. De functie berekent dan de procentuele verandering ten opzichte van het vorige kwartaal: (CPI<sub>kw</sub> / CPI<sub>kw−1</sub> − 1) × 100. De jaargrens (KW1 t.o.v. KW4 van het vorige jaar) wordt correct afgehandeld en de invoer wordt gevalideerd.
- `bereken_alle_mutaties()`: past dezelfde functie toe op alle beschikbare kwartalen.
- `controleer_jaargemiddelden()`: een plausibiliteitscontrole. Het gemiddelde van twaalf maanden wordt vergeleken met het jaarcijfer dat CBS zelf publiceert. De verschillen blijven binnen 0,01 indexpunt (afronding). Dat bevestigt dat de middelingsmethode overeenkomt met die van CBS.

**Output.**
- `cpi_index.png`: het verloop van de maandindex en het kwartaalgemiddelde per product.
- `cpi_kwartaalmutatie.png`: de kwartaalmutaties als staafdiagram (stijging oranje, daling blauw). Beide producten delen dezelfde y-as, zodat de grootte van de schommelingen direct vergelijkbaar is.
- `cpi_kwartaal.sqlite`: de tabellen `cpi_maand`, `cpi_kwartaal`, `kwartaalmutatie` en `run_info` (tabel, producten, tijdstip van de run, R-versie). Bij elke run worden de tabellen vervangen, zodat de database altijd overeenkomt met de laatste run.

Mutaties worden onafgerond opgeslagen. Afronding gebeurt alleen bij de presentatie.

## Uitkomsten in het kort

Olijfolie werd tussen 2022 en 2024 snel duurder. Die stijging hing samen met misoogsten in Zuid-Europa. Sinds 2025 daalt de prijs elk kwartaal. Hoofdtelefoons, e-readers en vergelijkbare producten laten een ander patroon zien: kleine schommelingen rond een licht dalende trend, met de prijs onder het niveau van 2015.

## Tooling

- R 4.6, RStudio
- `cbsodataR` voor de StatLine OData-API
- `dplyr` voor datatransformatie
- `ggplot2` voor grafieken
- `DBI` + `RSQLite` voor opslag
- Git/GitHub voor versiebeheer
