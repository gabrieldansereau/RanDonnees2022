## Extract data

# Required functions
source("required.R")

# Define target
target <- "QC"

# Raster data
message("(1/6) Loading & preparing the raster data")
env_stack <- prepare_rasters(target=target, type="env")
spe_stack <- prepare_rasters(target=target, type="spe")

# Tibbles
message("(2/6) Preparing the tibbles used in model training")
data_list <- prepare_tibbles(env_stack=env_stack, spe_stack=spe_stack)

# Data sets
env <- data_list$env
spe <- data_list$spe

## Summary data set for mentor presentation

# Prepare datasets
env_select <- env %>%
  select(site, lon, lat, wc1, wc6, wc12, lc1, lc3, lc6)
spe_select <- spe %>%
  select(site, sp1, sp23, sp26)

# Make pretty summary dataset
(var_select <- env_select %>%
  left_join(spe_select) %>%
  select(site, lon, lat, sp1, sp23, sp26, everything()) %>%
  mutate(wc1 = round(wc1/10, digits=3),
         wc6 = round(wc6/10, digits=3),
         wc12 = round(wc12, digits=0)) %>%
  rename(longitude = lon,
         latitude = lat,
         espece1 = sp1,
         espece2 = sp23,
         espece3 = sp26,
         climat1 = wc1,
         climat2 = wc6,
         climat3 = wc12,
         territoire1 = lc1,
         territoire2 = lc3,
         territoire3 = lc6
         )
)

# Export
# write_csv(head(var_select, 5), "../data/infos_ebird.csv")

## Select species with balanced observations

# Load name glossary
glossary <- read_csv("~/github/betadiversity-hotspots/data/proc/glossary.csv")

# Check balance of observations
tibble(sp = names(spe)[-c(1:3)], sum = colSums(spe)[-c(1:3)]) %>%
  mutate(perc = sum/nrow(spe)) %>%
  arrange(desc(perc)) %>%
  rename(variable = sp) %>%
  left_join(glossary) %>%
  print(n = Inf)

# Adapt glossary
(new_glossary <- glossary %>%
  filter(type == "species") %>%
  filter(variable %in% c("sp1", "sp23", "sp26")) %>%
  mutate(variable = c("sp1", "sp2", "sp3")) %>%
  bind_rows(filter(glossary, type == "climate")) %>%
  bind_rows(filter(glossary, type == "landcover"))
)

# Export
# write_csv(new_glossary, "../data/glossary.csv")

## Full dataset

# Select right species & prepare dataset
(dataset <- env %>%
  left_join(spe_select) %>%
  select(site, lon, lat, sp1, sp23, sp26, everything()) %>%
  rename(sp2 = sp23, sp3 = sp26)
)

# Export
# write_csv(dataset, "../data/dataset.csv")
