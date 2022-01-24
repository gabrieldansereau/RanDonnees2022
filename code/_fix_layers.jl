using SimpleSDMLayers

# Define extent
spatialrange = (left=-80.0, right=-56.0, bottom=44.0, top=62.0)

# Load the full layers
env = [geotiff(SimpleSDMPredictor, "./data/layers/warblers_env_full.tif", i; spatialrange...) for i in 1:29]
spe = [geotiff(SimpleSDMPredictor, "./data/layers/warblers_distributions_full.tif", i; spatialrange...) for i in 1:62]
spa = [geotiff(SimpleSDMPredictor, "./data/layers/warblers_spatial_full.tif", i; spatialrange...) for i in 1:3]

# Separate climate & landcover data
wc = env[1:19]
lc = env[20:end]

# Export
geotiff("./data/layers/warblers_climate.tif", wc)
geotiff("./data/layers/warblers_distributions.tif", spe)
geotiff("./data/layers/warblers_landcover.tif", lc)
geotiff("./data/layers/warblers_spatial.tif", spa)
