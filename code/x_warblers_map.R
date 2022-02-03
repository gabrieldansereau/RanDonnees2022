# Load packages
library(tidyverse)

# Load data
warblers <- read_csv("./data/warblers_dataset.csv")

# Define coordinates range for Quebec
lon_range = c(-80.0, -56.0)
lat_range =  c(44.0, 62.0)

# Load map data
worldmap <- map_data("world")
worldmap <- worldmap[worldmap$region %in% c("Canada", "USA"),]
# worldmap <- worldmap[lon_range[1] < worldmap$long & worldmap$long < lon_range[2],]
# worldmap <- worldmap[lat_range[1] < worldmap$lat & worldmap$lat < lat_range[2],]

# Create background map
naplot <- ggplot() +
  geom_polygon(data = worldmap, aes(x = long, y = lat, group = group),
               fill = "grey", color="grey") +
  coord_cartesian(xlim = lon_range, ylim = lat_range, expand = FALSE) +
  labs(x = "Longitude", y = "Latitude") +
  theme_bw()
naplot

# Add the observations
naplot +
  geom_point(data = warblers, aes(x = lon, y = lat))

# Plot the richness
richness <- warblers %>%
  mutate(richness = sp1 + sp2 + sp3) %>%
  select(-starts_with("wc"), -starts_with("lc"))
naplot +
  geom_point(data = richness, aes(x = lon, y = lat, colour=richness))
