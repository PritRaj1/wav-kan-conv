module MexicanHat

export MexicanHatWavelet

include("../../utils.jl")

using Flux, CUDA, KernelAbstractions, Tullio
using .UTILS: node_mul_1D, node_mul_2D

bool_2D = parse(Bool, get(ENV, "2D", "false"))
node = bool_2D ? node_mul_2D : node_mul_1D

function batch_mul_1D(x, y)
    return @tullio out[i, o, b] := x[i, o, b] * y[i, o, b]
end

function batch_mul_2D(x, y)
    return @tullio out[i, o, l, b] := x[i, o, l, b] * y[i, o, l, b]
end

batch_mul = bool_2D ? batch_mul_2D : batch_mul_1D

one = [1] |> gpu
exp_norm = [-1 / 2] |> gpu
normalisation = [2 / sqrt(3 * sqrt(π))] |> gpu

struct MHWavelet
    weights::AbstractArray
end

function MexicanHatWavelet(weights)
    return MHWavelet(weights)
end

function (w::MHWavelet)(x)
    term_1 = x.^2 .- one
    term_2 = exp.(x.^2 .* exp_norm)
    y = batch_mul(term_1, term_2)
    y = y .* normalisation
    return node(y, w.weights)
end

Flux.@functor MHWavelet

end 