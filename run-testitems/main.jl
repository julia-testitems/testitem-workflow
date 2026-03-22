using TestItemRunnerCore, JSON, Logging
using JuliaWorkspaces.URIs2: URI

if ARGS[1] == "nodebug"
    global_logger(ConsoleLogger(Warn))
elseif ARGS[1] == "debug"
    ENV["JULIA_DEBUG"] = "Main,TestItemRunnerCore,TestItemControllers"
else
    error("Unknown command line argument $(ARGS[1]).")
end

env_dict = Dict{String,Any}()

test_env_str = get(ENV, "TEST_ENV", "")
if test_env_str != ""
    for (k,v) in JSON.parse(test_env_str)
        env_dict[k] = v
    end
end

juliaup_channel = get(ENV, "TEST_JULIAUP_CHANNEL", "release")
if isempty(juliaup_channel)
    juliaup_channel = "release"
end

env_dict["JULIAUP_CHANNEL"] = juliaup_channel
env_dict["JULIA_DEPOT_PATH"] = nothing

filter_func = nothing
filter_expr_str = get(ENV, "TEST_FILTER", "")
if !isempty(filter_expr_str)
    filter_expr = Meta.parse(filter_expr_str)
    filter_func = eval(:(i -> let name=i.name, tags=i.tags, filename=i.filename, package_name=i.package_name
        $filter_expr
    end))
end

testitem_timeout = parse(Int, get(ENV, "TEST_TIMEOUT", "1200"))

profile_name = get(ENV, "TEST_PROFILE_NAME", "")
if isempty(profile_name)
    profile_name = "Default"
end

results = run_tests(
    pwd(),
    filter=filter_func,
    fail_on_detection_error=false,
    return_results=true,
    print_failed_results=true,
    progress_ui=:log,
    timeout=testitem_timeout,
    environments=[RunProfile(profile_name, false, env_dict)]
)

at_least_one_fail = false

for ti in results.testitems
    for p in ti.profiles
        if p.status != :passed
            global at_least_one_fail = true
            break
        end
    end
end

JSON.lower(uri::URI) = string(uri)

results_path = get(ENV, "RESULTS_PATH", "")
if !isempty(results_path)
    open(results_path, "w") do f
        JSON.print(f, results)
    end
end

kill_test_processes()

if at_least_one_fail
    exit(1)
end
