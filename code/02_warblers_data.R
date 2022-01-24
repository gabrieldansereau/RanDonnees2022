## Extract data

# Required functions
source("code/required.R")

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
env_example <- env %>%
  select(site, lon, lat, wc1, wc6, wc12, lc1, lc3, lc6)
spe_example <- spe %>%
  select(site, sp1, sp23, sp26)

# Make pretty summary dataset
(var_example <- env_example %>%
  left_join(spe_example) %>%
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
write_csv(head(var_example, 5), "./data/warblers_example.csv")

## Select species with balanced observations

# Load name glossary
glossary_env <- read_csv("~/github/betadiversity-hotspots/data/proc/glossary.csv") %>%
  filter(type != "species")
glossary_spe <- read_csv("~/github/PoisotLab/betadiversity-forecasts/data/output/species_list.csv") %>%
  rename(variable = id, full_name = species, description = common_name) %>%
  mutate(type = "species", .after = variable)
glossary_spe
glossary_env

# Check balance of observations
tibble(sp = names(spe)[-c(1:3)], sum = colSums(spe)[-c(1:3)]) %>%
  mutate(perc = sum/nrow(spe)) %>%
  arrange(desc(perc)) %>%
  rename(variable = sp) %>%
  left_join(glossary_spe) %>%
  print(n = Inf)

# Choose species
selected_species <- c(
  # "sp10", # Pine warbler, 0.366
  # "sp18", # Black-throated Blue warbler, 0.587
  "sp29", # Canada warbler, 0.556
  "sp28", # Cape May Warbler, 0.561
  "sp3" # Yellow warbler, 0.738
)
plot(spe_stack[[selected_species]])

# Adapt glossary
(new_glossary <- glossary_spe %>%
  filter(variable == selected_species[1]) %>%
  bind_rows(filter(glossary_spe, variable == selected_species[2])) %>%
  bind_rows(filter(glossary_spe, variable == selected_species[3])) %>%
  mutate(variable = c("sp1", "sp2", "sp3")) %>%
  bind_rows(filter(glossary_env, type == "climate")) %>%
  bind_rows(filter(glossary_env, type == "landcover"))
)

# Export
write_csv(new_glossary, "./data/warblers_glossary.csv")

## Full dataset

# Select right species
spe_selected <- spe %>%
  select(site, lon, lat, selected_species) %>%
  rename(sp1 = 4, sp2 = 5, sp3 = 6)
spe_selected

# Prepare full dataset
(dataset <- spe_selected %>%
  left_join(env) %>%
  select(site, lon, lat, everything())
)

# Export
write_csv(dataset, "./data/warblers_dataset.csv")
