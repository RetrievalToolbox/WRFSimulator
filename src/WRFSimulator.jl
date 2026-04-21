module WRFSimulator

    using ArgParse
    using Dates
    using Distances
    using Distributed
    #using FastInterpolations
    using NCDatasets
    using NearestNeighbors
    using OrderedCollections
    using ProgressMeter
    using Unitful
    using YAML

    using RetrievalToolbox
    const RE = RetrievalToolbox

    using RESimulatorCore

    include("create_windows.jl")
    include("create_gases.jl")
    include("surface_parameters.jl")

    include("create_global_config.jl")
    include("read_WRF.jl")
    include("output.jl")


    function parse_commandline()

        s = ArgParseSettings(description = "WRF RT Simulator")

        @add_arg_table! s begin
            "--WRF", "-i"
                help = "Path to the input WRF NetCDF file"
                required = true
            "--windows", "-w"
                help = "Path to windows YML file"
                required = true
            "--gases", "-g"
                help = "Path to gases YML file"
                required = true
            "--TSIS"
                help = "Path to TSIS solar model file"
                required = true
            "--coords"
                help = "Path to CSV file containing the lon/lat pairs"
                required = true
            "--output", "-o"
                help = "Path to save the simulated radiances"
                required = true
            "--procs", "-p"
                help = "Number of *additional* processes to use"
                arg_type = Int
                default = 0
            "--neighbors", "-N"
                help = "Number of nearest neighbors for spatial interpolation"
                arg_type = Int
                default = 1
        end

        return parse_args(ARGS, s)
    end

    function main()

        # Check for XRTM
        if !haskey(ENV, "XRTM_PATH")
            error("XRTM_PATH environmental variable not set! \
                Please set it to the location of the XRTM library.")
            exit(1)
        end


        # Parse arguments
        args = parse_commandline()

        # NN must be >= 0
        if args["neighbors"] < 1
            error("Number of nearest neighbors for spatial interpolation must be >= 1.")
        end


        if args["procs"] > 0
            @info "Adding $(args["procs"]) extra processes."
            addprocs(args["procs"])
        end

        @everywhere @eval using RESimulatorCore
        @everywhere @eval using WRFSimulator

        # Create the global config on the main worker, and then copy to all others. This
        # ensures that the spectroscopy objects will be shared across all workers, while
        # only one copy has to exist in memory.
        global_config = WRFSimulator.create_global_config(
            args["windows"],
            args["gases"],
            args["TSIS"],
            47,
            47
        )

        # Let all workers have their own local copy
        @everywhere global_config = $global_config

        # Create the RetrievalToolbox buffer. THIS MUST BE DONE SEPARATELY ON ALL WORKERS
        # - OTHERWISE THE CRUCIAL OBJECT HASHING MECHANISM DOES NOT WORK!
        buffer = RESimulatorCore.create_buffer(global_config)
        @everywhere buffer = $buffer


        #=
            Ingest coordinates to be sampled
        =#

        _raw_coord_txt = readlines(args["coords"])
        lonlat_array = zeros(2, length(_raw_coord_txt))
        for i in 1:length(_raw_coord_txt)
            lonlat_array[:,i] = parse.(Ref(Float64), split(_raw_coord_txt[i], ","))
        end

        @info "Creating scenes from WRF file .."
        all_scenes = WRFSimulator.generate_scenes_from_WRF(
            global_config,
            args["WRF"],
            buffer,
            lonlat_array;
            NN=args["neighbors"]
        )

        @sync @everywhere @info "(synchronizing)"

        @info "Processing $(length(all_scenes)) scenes!"
        if nworkers() > 1
            @info "(parallel processing: $(nprocs()))"
            @time results = @showprogress showspeed=true @distributed (vcat) for scene in all_scenes
                [RESimulatorCore.process_scene!(buffer, scene)]
            end
        else
            results = []
            @showprogress showspeed=true for scene in all_scenes
                push!(results, RESimulatorCore.process_scene!(buffer, scene))
            end
        end

        WRFSimulator.write_out(args["output"], global_config, all_scenes, results, buffer)

    end

end
