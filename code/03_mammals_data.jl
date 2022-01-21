# Load packages
using CSV
using DataFramesMeta
using GBIF
using Pipe
using Plots
using SimpleSDMLayers
default(dpi=200)

## Preparation

# Define range for Quebec
# extent(-80.0, -56.0, 44.0, 62.0)
# spatialrange = (left=-80., right=-50., bottom=45., top=65.)
spatialrange = (left=-80., right=-50., bottom=44., top=65.)
lon = (spatialrange.left, spatialrange.right)
lat = (spatialrange.bottom, spatialrange.top)

# Define reference layer
temperature = SimpleSDMPredictor(WorldClim, BioClim, 1; spatialrange...)

# Define species
species = ["Vulpes vulpes", "Tamias striatus", "Marmota monax"]
species_en = ["Red Fox", "Eastern Chipmunk", "Groundhog"]

## Extract data

# Wrap everything in one function
function gimme_mammals_pls(sp::String)
    # Replace spaces
    _sp = replace(sp, " " => "_")

    # Define taxons
    sp_code = taxon(sp, rank = :SPECIES)

    # Query parameters
    observations = occurrences(
        sp_code,
        "limit" => 300,
        "hasCoordinate" => "true",
        "decimalLatitude" => lat,
        "decimalLongitude" => lon,
    )

    # Retrieve all
    while length(observations) < size(observations)
        occurrences!(observations)
    end

    # Check the data
    obs_df = DataFrame(observations)

    ## Layers

    # Plot to see occurrences
    p_obs = contour(temperature; c=:cork, frame=:box, fill=true, clim=(-20, 20), levels=6, title=sp)
    scatter!(
        longitudes(observations), latitudes(observations); lab="", c=:white, msc=:orange, ms=3
    )
    savefig(joinpath("figures", "obs_$(_sp).png"))

    # Layer with the number of observations per cell
    p_counts = counts = mask(temperature, observations, Float32)
    plot(log1p(counts); c=:tokyo, title=sp)
    savefig(joinpath("figures", "counts_$(_sp).png"))

    # Check the number of pixels with observations
    # presabs = replace(counts, 0.0 => nothing)
    presabs = @pipe mask(temperature, observations, Bool) |>
        convert(Float32, _) |>
        replace(_, 0.0 => nothing)

    # Plot
    p_presabs = plot(temperature, c=:lightgrey)
    plot!(presabs; c=:BuPu, cb=:none, title=sp)
    savefig(joinpath("figures", "presabs_$(_sp).png"))

    # Export elements
    results = (
        occurrences = occurrences,
        obs_df = obs_df,
        p_obs = p_obs,
        counts = counts,
        p_counts = p_counts,
        presabs = presabs,
        p_presabs = p_presabs
    )

    return results
end

# Get the data for the three species
sp1 = gimme_mammals_pls(species[1]);
sp2 = gimme_mammals_pls(species[2]);
sp3 = gimme_mammals_pls(species[3]);

# Prepare a prettier figure as an exemple
foxplot = sp1.p_obs
title!(foxplot, "Observations du Renard roux")
xaxis!("Longitude")
yaxis!("Latitude")
plot!(colorbar_title="Température moyenne")
savefig(joinpath("figures", "exemple_renard.png"))

## Assemble dataset

# Combine observations in single DataFrame
combined_df = vcat(sp1.obs_df, sp2.obs_df, sp3.obs_df)
unique(combined_df.name)

# Export
CSV.write(joinpath("data", "mammals_occurrences.csv"), combined_df)

# Assemble layers
layers = [sp1.presabs, sp2.presabs, sp3.presabs]

# Export
geotiff(joinpath("data", "mammals_layers.csv"), layers)

# Convert layers to DataFrame
layers_df_full = DataFrame(layers)
rename!(layers_df_full, "x1" => "sp1", "x2" => "sp2", "x3" => "sp3")

# Remove sites without observations
layers_df = filter(x -> any(!ismissing, [x.sp1, x.sp2, x.sp3]), layers_df_full)

# Verify species co-occurrence
layers_df.sum = map(x -> sum(skipmissing([x.sp1, x.sp2, x.sp3])), eachrow(layers_df))
layers_df
unique(layers_df.sum)
@chain begin layers_df
    groupby(:sum)
    combine(nrow)
end

# Verify the occupancy ratio & pixel count
@chain layers_df begin
    describe(:min, :max, :nmissing)
    @rtransform(:n = nrow(layers_df) - :nmissing)
    @rsubset(String(:variable) in ["sp1", "sp2", "sp3"])
    @rtransform(:ratio = :n / nrow(layers_df))
    @transform(:equal_layer = :n .== length.(layers))
end
# Seems reasonable

## Combine with environmental data

# Load glossary
glo_path = "$(homedir())/github/betadiversity-hotspots/data/proc/glossary.csv"
glossary = CSV.read(glo_path, DataFrame)
filter!(:type => !=("species"), glossary)
glossary = vcat(
    filter(:type => ==("climate"), glossary),
    filter(:type => ==("landcover"), glossary)
)

# Add new species
glossary_sp = DataFrame(
    variable = ["sp1", "sp2", "sp3"],
    type = "species",
    full_name = replace.(species, " " => "_"),
    description = species_en
)
glossary = vcat(glossary_sp, glossary)

# Load env data
nlayers = nrow(filter(:type => !=("species"), glossary))
env_path = "$(homedir())/github/betadiversity-hotspots/data/raster/env_stack.tif"
env_layers = [geotiff(SimpleSDMPredictor, env_path, i; spatialrange...) for i in 1:nlayers]

# Verify the data
size(env_layers[1]) == size(layers[1])
boundingbox(env_layers[1]) == boundingbox(layers[1])
env_layers[1] == temperature

# Arrange as DataFrame
env_df = DataFrame(env_layers)
env_names = filter(:type => !=("species"), glossary).variable
rename!(env_df, ["longitude", "latitude", env_names...])

# Combine with species data
full_df = leftjoin(select(layers_df, Not(:sum)), env_df, on=[:longitude, :latitude])

# Export
CSV.write("./data/mammals_complete.csv", full_df)
CSV.write("./data/mammals_env.csv", env_df)
CSV.write("./data/mammals_glossary.csv", glossary)