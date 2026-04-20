# WRFSimulator

> [!WARNING]
> WRFSimulator is currently in stages of very early development. The package may not fully work.

## Installation

We recommend installing **WRFSimulator** by cloning the source, instantiating the project with Julia's package/project manager `Pkg`, and using the script in `bin/simulator` to run it. This way, users can freely adjust the scripts within to suit their particular use case, which would not be possible if **WRFSimulator** was installed directly from the Julia package manager.

First, ensure that a recent version of Julia (> 1.12) is installed. **WRFSimulator** is based on the [RetrievalToolbox.jl](https://github.com/US-GHG-Center/RetrievalToolbox.jl) library, and also relies on a working installation of the **XRTM** radiative transfer code. The RetrievalToolbox repository has documentation on how the library can be correctly installed on Mac and Unix/Linux platforms.

Assuming a working Julia environment, and XRTM having been correctly compiled, with the environment variable `XRTM_PATH` pointing to the location of XRTM, proceed as follows.

To install the required dependencies:

    julia --project=. -e 'using Pkg; Pkg.instantiate()'

A quick check to see if the needed modules are indeed available (replace `/path/to/XRTM` with the actual path, possibly enable execution permissions for `bin/simulator`):

    XRTM_PATH=/path/to/XRTM ./bin/simulator --help

## Running

    julia --project=. ./bin/simulator \
        --WRF /path/to/WRF/file
        --OUTPUT output.h5 \
        --GASES example_data/gases.yml \
        --WINDOWS example \
        --NEIGHBORS 4
