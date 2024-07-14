module manual_conv

include("KAN_layers.jl")

export KAN_conv2D

using LinearAlgebra
using Statistics
using Flux, CUDA, KernelAbstractions, Tullio
using .layers: KANdense

function calc_out_dims(matrix, kernel_size, stride, dilation, padding)
    n, m, n_channels, batch_size = size(matrix)
    h_out = floor(Int, (n + 2 * padding - kernel_size - (kernel_size - 1) * (dilation - 1)) / stride) + 1
    w_out = floor(Int, (m + 2 * padding - kernel_size - (kernel_size - 1) * (dilation - 1)) / stride) + 1
    return n, h_out, w_out, n_channels, batch_size
end

# Extract sliding local blocks from a batched input tensor.
function unfold(input, kernel_size; stride=1, padding=0, dilation=1)
    H, W, C, N = size(input)
    kh, kw = kernel_size
    sh, sw = stride isa NTuple ? stride : (stride, stride)
    ph, pw = padding isa NTuple ? padding : (padding, padding)
    dh, dw = dilation isa NTuple ? dilation : (dilation, dilation)

    out_h = div(H + 2ph - (dh * (kh - 1) + 1), sh) + 1
    out_w = div(W + 2pw - (dw * (kw - 1) + 1), sw) + 1

    output = zeros(kh, kw, out_h, out_w, C, N) |> gpu

    padded_input = zeros(H + 2ph, W + 2pw, C, N) |> gpu
    padded_input[ph + 1:ph + H, pw + 1:pw + W, :, :] = input

    for i in 1:kh
        for j in 1:kw
            h_start = (i - 1) * dh + 1
            w_start = (j - 1) * dw + 1
            h_indices = h_start:sh:(h_start + sh * (out_h - 1))
            w_indices = w_start:sw:(w_start + sw * (out_w - 1))
            output[i, j, :, :, :, :] .= padded_input[h_indices, w_indices, :, :]
        end
    end

    return output
end

function add_padding(matrix, padding=0)
    n, m, n_channels, batch_size = size(matrix)
    matrix_padded = CUDA.zeros(n + 2 * padding, m + 2 * padding, n_channels, batch_size)
    matrix_padded[padding + 1:end - padding, padding + 1:end - padding, :, :] = matrix
    return matrix_padded
end

function KAN_conv2D(matrix, kernel, kernel_size, stride=1, dilation=0, padding=0)
    n, h_out, w_out, n_channels, batch_size = calc_out_dims(matrix, kernel_size, stride, dilation, padding)
    matrix_out = zeros(h_out, w_out, n_channels, batch_size) |> gpu

    for channel in 1:n_channels
        conv_groups = unfold(matrix[:, :, channel:channel, :], (kernel_size, kernel_size); stride, padding, dilation)
        conv_groups = reshape(conv_groups, kernel_size * kernel_size, h_out * w_out, batch_size)
        
        for batch in 1:batch_size
            matrix_out[:, :, channel, batch] = kernel(conv_groups[:, :, batch])
        end
    end

    return matrix_out
end
end

