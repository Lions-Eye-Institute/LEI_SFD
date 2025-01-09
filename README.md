# Lions Eye Institute Structure-Function Dataset (LEI-SFD)

If you use any part of this dataset, please cite 
> Under submission to TVST, awaiting peer review (Jan 2025).


This repository contains synthetic datasets derived from clinical data on glaucomatous eyes. 
It also contains code to generate new "measured" (or noisy) data from the canonical "True" dataset provided.
The intent is that these dataset would be used to aid research into new analytical methods for detecting glaucomatous progression.

See [datasheet.md](datasheet.md) for more details.

## Usage

The data is in csv files in the [LEI_SFD1](LEI_SFD1) folder. The [LEI_Rapid](LEI_Rapid) folder contains some artificial data that is similar to the LEI-SFD but with much faster (artificial) progressing rates.

To generate new datasets from the ground truth `true.csv`, use  the `generate_synthetic_data(...)` function in [generate.r](generate.r). Something like (within R with the working directory set to the location of this repo)

```
source("generate.r")

  # Uses current time as the random seed.
generate_synthetic_data(Sys.time(),
  noise = "unreliable_gve", 
  output_filename = "my_unreliable_gve.csv")

  # Customise the noise with 10% false positive and negative responses and no GVE
generate_synthetic_data(Sys.time(),
  noise = "custom",
  fpr = 0.1, fnr = 0.1, gve = FALSE,
  output_filename = "my_p10n10.csv")
```

## Updates

If the community finds this a useful resource, we will add more eyes in the future (claims [Andrew Turpin](mailto:andrew.turpin@lei.org.au), Jan 2025).

The current/past datasets will remain unchanged for consistent benchmarking. New data will be added in new folders with new version numbers (eg LEI_SFD2).

If you wish to contribute data to the LEI-SFD, please contact [Andrew Turpin](mailto:andrew.turpin@lei.org.au), 
or create a new subfolder (use a short name and version number, please).