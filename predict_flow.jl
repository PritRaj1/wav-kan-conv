include("src/pipeline/data_processing/data_loader.jl")
include("src/models/MLP_CNN/CNN.jl")
include("src/models/MLP_FNO/FNO.jl")
include("src/models/wavKAN_CNN/KAN_CNN.jl")

using Plots; pythonplot()
using Flux
using BSON: @load
using CUDA, KernelAbstractions
using .loaders: get_darcy_loader

train_loader, test_loader = get_darcy_loader(1)

MODEL_NAME = "MLP CNN"

model_file = Dict(
    "MLP CNN" => "src/models/MLP_CNN/logs/trained_models/model_1.bson",
    "MLP FNO" => "src/models/MLP_FNO/logs/trained_models/model_1.bson",
    "KAN CNN" => "src/models/wavKAN_CNN/logs/trained_models/model_1.bson"
)[MODEL_NAME]

# Load the model
@load model_file model

# Move the model to the GPU
model = gpu(model)

X, Y = [x for x in range(0, stop=1, length=32)], [y for y in range(0, stop=1, length=32)]

# Plot the prediction
anim = @animate for (a, u) in test_loader
    u_pred = model(a) |> cpu
    u_pred = u_pred[:, :, 1, 1]
    contourf(X, Y, u_pred, title="$MODEL_NAME Prediction", cbar=false, color=:viridis, aspect_ratio=:equal)
end

# Save the animation to file
gif(anim, "figures/$MODEL_NAME" * "_prediction.gif", fps=5)

# Plot the error field
anim = @animate for (a, u) in test_loader
    u_pred = model(a) |> cpu
    u_pred = u_pred[:, :, 1, 1]
    u = u |> cpu
    u = u[:, :, 1, 1]
    contourf(X, Y, u_pred .- u, title="$MODEL_NAME Error Field", cbar=false, color=:viridis, aspect_ratio=:equal)
end

# Save the animation to file
gif(anim, "figures/$MODEL_NAME" * "_error.gif", fps=5)

