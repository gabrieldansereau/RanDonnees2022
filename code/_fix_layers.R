# Required functions
source("code/required.R")

# Load the full layers
wc_full <- stack("./data/layers/warblers_climate_full.tif")
sp_full <- stack("./data/layers/warblers_distributions_full.tif")
lc_full <- stack("./data/layers/warblers_landcover_full.tif")
spa_full <- stack("./data/layers/warblers_spatial_full.tif")

# Crop to selected extent
spatialrange <- extent(-80.0, -56.0, 44.0, 62.0)
lc <- crop(lc_full, spatialrange)
sp <- crop(sp_full, spatialrange)
wc <- crop(wc_full, spatialrange)
spa <- crop(spa_full, spatialrange)

# Export
writeRaster(lc, "./data/layers/warblers_climate.tif", "GTiff", overwrite=TRUE)
writeRaster(sp, "./data/layers/warblers_distributions.tif", "GTiff", overwrite=TRUE)
writeRaster(wc, "./data/layers/warblers_landcover.tif", "GTiff", overwrite=TRUE)
writeRaster(spa, "./data/layers/warblers_spatial.tif", "GTiff", overwrite=TRUE)
