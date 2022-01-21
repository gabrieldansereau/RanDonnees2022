## 0. Load packages ####
## Load required R packages

# Avoid function names conflicts
library(conflicted)

# Load packages
library(embarcadero)
library(furrr)
library(here)
library(ncdf4)
library(raster)
library(rgdal)
library(tictoc)
library(tidyverse)
library(vegan)
library(viridis)

# Select parallel processing option
if (future::supportsMulticore()) {
    future::plan(future::multicore) # Preferred option when possible (Linux & Mac, not on RStudio)
} else {
    future::plan(future::multisession) # For Windows and RStudio (also works on Linux & Mac)
}

# Resolve conflicts
conflict_prefer("filter", "dplyr")
conflict_prefer("intersect", "dplyr")
conflict_prefer("select", "dplyr")

## BEGIN FUNCTION DEFINITION ####

## 1. Load & prepare raster data ####

## Load & prepare the environmental & species rasters
prepare_rasters <- function(target, type, year=2020) {
  # Verify arguments
  stopifnot("target must be \"QC\" or \"CO\"" = target %in% c("QC", "CO"))
  stopifnot("type must be \"env\", \"spe\", or \"lcbd\"" = type %in% c("env", "spe", "lcbd"))
  stopifnot("year must be 2020, 2050, or 2070" = year %in% c(2020, 2050, 2070))

  # Define target extent
  if (target == "QC") {
    # Extent for Quebec
    raster_extent <- extent(-80.0, -56.0, 44.0, 62.0)
  } else {
    # Extent for Colombia
    raster_extent <- extent(-82.0, -66.0, -4.5, 14.0)
  }

  # Select raster files
  repo_path <- "~/github/PoisotLab/betadiversity-forecasts/"
  if (type == "env") {
    # Environmental files
    files <- list(
      here(repo_path, "data", "species", "spatial_data.tif"), # spatial data
      here(repo_path, "data", "bioclim", paste0("BIO_", year, ".tif")), # climate
      here(repo_path, "data", "landcover", paste0("landcover_", year, ".tif")) # land cover
    )
  } else if (type == "spe") {
    # Species files
    files <- list(
      here(repo_path, "data", "species", "spatial_data.tif"),
      here(repo_path, "data", "species", "ebird_distributions.tif")
    )
  } else {
    # LCBD values (useful in other script)
    files <- list(
      here(repo_path, "data", "lcbd", paste0(tolower(target), "_lcbd_2020.tif"))
    )
  }

  # Load rasters as stack
  rasters <- stack(files)

  # Crop to selected extent
  rasters <- crop(rasters, raster_extent)

  # Rename variables
  if (type == "env") {
    names(rasters) <- c("site", "lon", "lat", paste0("wc", 1:19), paste0("lc", 1:14))
  } else if (type == "spe") {
    names(rasters) <- c("site", "lon", "lat", paste0("sp", 1:(nlayers(rasters)-3)))
  } else {
    names(rasters) <- c("lcbd")
  }

  # Remove empty species rasters (species not present in subset)
  if (type == "spe") {
    (inds_empty <- which(is.na(minValue(rasters))))
    if (length(inds_empty) > 0) {
      message("Removing ", length(inds_empty), " species without observations")
      rasters <- rasters[[-inds_empty]]
    }
  }

  return(rasters)
}

## 2. Prepare data for model training ####

# Prepare environmental & species tibbles used in model training
prepare_tibbles <- function(env_stack, spe_stack) {
  # Convert to tibble
  env_full <- as_tibble(as.data.frame(env_stack))
  spe_full <- as_tibble(as.data.frame(spe_stack))

  # Reorder rows by site id (same order as SimpleSDMLayers)
  env_full <- arrange(env_full, site)
  spe_full <- arrange(spe_full, site)

  # Select sites with observations only & replace NAs by zeros
  spe <- spe_full %>%
    filter(if_any(contains("sp") | contains("lcbd"), ~ !is.na(.x))) %>%
    mutate(across(contains("sp") | contains("lcbd"), ~ replace(., is.na(.), 0)))
  env <- filter(env_full, site %in% spe$site)

  # Remove site with NAs for some environmental variables
  inds_withNAs <- unique(unlist(map(env, ~ which(is.na(.x)))))
  if (length(inds_withNAs) > 0) {
    message("Removing ", length(inds_withNAs), " sites with observations but NA for some environmental variables")
    spe <- spe[-inds_withNAs,]
    env <- env[-inds_withNAs,]
  }

  # Remove variables which are all zeros at species occurrences
  env_withoutvalues <- names(which(colSums(env) == 0))
  if (length(env_withoutvalues) > 0) {
    message("Removing ", length(env_withoutvalues), " variable without values")
    env <- dplyr::select(env, -all_of(env_withoutvalues))
    env_full <- dplyr::select(env_full, -all_of(env_withoutvalues))
  }

  # Remove spatial variables
  xnames <- names(select(env, -c("site", "lon", "lat")))
  vars_stack <- subset(env_stack, xnames)

  # Assemble prepared_data
  data_list <- list(
    env = env,
    spe = spe,
    xnames = xnames,
    vars_stack = vars_stack
  )

  return(data_list)
}
