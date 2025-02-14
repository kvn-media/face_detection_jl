#!/usr/bin/env bash
#=
exec julia --project="$(realpath $(dirname $0))/" "${BASH_SOURCE[0]}" "$@" -e "include(popfirst!(ARGS))" \
"${BASH_SOURCE[0]}" "$@"
=#


#=
Adapted from https://github.com/Simon-Hohberg/Viola-Jones/
=#


# println("\033[1;34m===>\033[0;38m\033[1;38m\tLoading required libraries (it will take a moment to precompile if it is your first time doing this)...\033[0;38m")
@info "Loading required libraries (it will take a moment to precompile if it is your first time doing this)..."

include(joinpath(dirname(@__DIR__), "src", "FaceDetection.jl"))

using .FaceDetection
const FD = FaceDetection
using Printf: @printf
using Images: imresize
using Serialization: deserialize

@info("...done\n")

function main(;
    smart_choose_feats::Bool = false,
    scale::Bool = false,
    scale_to::Tuple = (200, 200),
)

    include("constants.jl")
    include("main_data.jl")

    max_feature_width,
    max_feature_height,
    min_feature_height,
    min_feature_width,
    min_size_img = determine_feature_size(
        pos_testing_path,
        neg_testing_path;
        scale = scale,
        scale_to = scale_to,
    )
    img_size = scale ? scale_to : min_size_img
    img_width, img_height = min_size_img
    data_file = joinpath(@__DIR__, "data", "feature_votes_$(img_size)")

    if !isfile(data_file)
        error(
            throw(
                "You do not have a data file.  Ensure you run \"write.jl\" to obtain your feature votes before running this programme.",
            ),
        )
    end

    # read classifiers from file
    votes, features = deserialize(data_file)
    classifiers =
        FD.learn(pos_training_path, neg_training_path, features, votes, num_classifiers)

    @info("Testing selected classifiers...")
    num_faces = length(filtered_ls(pos_testing_path))
    num_non_faces = length(filtered_ls(neg_testing_path))

    correct_faces = sum(
        FD.ensemble_vote_all(
            pos_testing_path,
            classifiers,
            scale = scale,
            scale_to = scale_to,
        ),
    )
    correct_non_faces =
        num_non_faces - sum(
            FD.ensemble_vote_all(
                neg_testing_path,
                classifiers,
                scale = scale,
                scale_to = scale_to,
            ),
        )
    correct_faces_percent = (correct_faces / num_faces) * 100
    correct_non_faces_percent = (correct_non_faces / num_non_faces) * 100

    faces_frac = string(correct_faces, "/", num_faces)
    faces_percent =
        string("(", correct_faces_percent, "% of faces were recognised as faces)")
    non_faces_frac = string(correct_non_faces, "/", num_non_faces)
    non_faces_percent = string(
        "(",
        correct_non_faces_percent,
        "% of non-faces were identified as non-faces)",
    )

    @info("...done.\n")
    @info("Result:\n")

    @printf("%10.9s %10.15s %15s\n", "Faces:", faces_frac, faces_percent)
    @printf("%10.9s %10.15s %15s\n\n", "Non-faces:", non_faces_frac, non_faces_percent)
end

@time main(smart_choose_feats = true, scale = true, scale_to = (20, 20))