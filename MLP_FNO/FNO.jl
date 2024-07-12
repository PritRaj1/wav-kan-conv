module FourierNO

export FNO

include("../utils.jl")
include("./FNO_block.jl")
include("./FNO_layers.jl")

using .UTILS: get_grid
using .FNO_block: FNO_hidden_block
using .FNO_layers: MLP

using CUDA, KernelAbstractions, Tullio
using Flux
using Flux: Conv, Dense
using ConfParser
using NNlib

conf = ConfParse("FNO_config.ini")
parse_conf!(conf)

width = parse(Int, retrieve(conf, "Architecture", "channel_width"))
activation = retrieve(conf, "Architecture", "activation")
num_blocks = parse(Int, retrieve(conf, "Architecture", "num_hidden_blocks"))

# Activation mapping
act_fcn = Dict(
    "relu" => NNlib.relu,
    "leakyrelu" => NNlib.leakyrelu,
    "tanh" => NNlib.hardtanh,
    "sigmoid" => NNlib.hardsigmoid,
    "swish" => NNlib.hardswish,
    "gelu" => NNlib.gelu
)[activation]

struct FNO
    input_layer
    hidden_layers
    output_layer
end

# Construct the FNO model
function FNO(in_channels::Int, out_channels::Int)
    phi = act_fcn

    input_layer = Dense(3 => width, phi)
    hidden_blocks = [FNO_hidden_block(width, width) for _ in 1:num_blocks]
    
    output_MLP =  MLP(width, 1, width * 4)
    return FNO(input_layer, Chain(hidden_blocks...), output_MLP)
end

function (m::FNO)(x)
    x = get_grid(x)
    x = m.input_layer(x)
    x = @tullio z[i, j, k, b] := x[k, i, j, b]
    x = m.hidden_layers(x)
    x = m.output_layer(x)
    return x
end

Flux.@functor FNO

end