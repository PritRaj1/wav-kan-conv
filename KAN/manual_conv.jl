module manual_conv

include("../utils.jl")

export KAN_conv2D

using LinearAlgebra
using Statistics
using Flux, CUDA, KernelAbstractions, Tullio
using .UTILS: unfold

function calc_out_dims(matrix, kernel_size, stride, dilation, padding)
    n, m, n_channels, batch_size = size(matrix)
    h_out = floor(Int, (n + 2 * padding - kernel_size[1] - (kernel_size[1] - 1) * (dilation - 1)) / stride) + 1
    w_out = floor(Int, (m + 2 * padding - kernel_size[2] - (kernel_size[2] - 1) * (dilation - 1)) / stride) + 1
    return h_out, w_out, n_channels, batch_size
end

function add_padding(matrix, padding=0)
    n, m, n_channels, batch_size = size(matrix)
    matrix_padded = CUDA.zeros(n + 2 * padding, m + 2 * padding, n_channels, batch_size)
    matrix_padded[padding + 1:end - padding, padding + 1:end - padding, :, :] = matrix
    return matrix_padded
end

function KAN_conv2D(matrix, kernel, kernel_size, stride=1, dilation=1, padding=0)
    h_out, w_out, n_channels, batch_size = calc_out_dims(matrix, kernel_size, stride, dilation, padding)
    matrix_out = zeros(h_out, w_out, n_channels, batch_size) |> gpu

    for channel in 1:n_channels
        conv_groups = unfold(matrix[:, :, channel:channel, :], kernel_size; stride, padding, dilation)
        conv_groups = reshape(conv_groups, kernel_size[1] * kernel_size[2], h_out * w_out, batch_size)
    
        for batch in 1:batch_size
            matrix_out[:, :, channel, batch] = kernel(conv_groups[:, :, batch])
        end
    end

    return matrix_out
end
end

