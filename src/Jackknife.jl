"""
**Jackknife** errors for (non-linear) functions of uncertain data, i.e. g(<a>,<b>,...)

Inspired by https://github.com/ararslan/Jackknife.jl.
"""
module Jackknife

using EllipsisNotation
import Statistics: mean, var

export jackknife_full, jackknife


"""
    jackknife_full(g::Function, x::AbstractMatrix) -> je, jstd

Jackknife estimate `je` and standard error `jstd` of `g(<a>,<b>,...)`.

Columns of `x` are time series of random variables, i.e. `x[i,1] = a_i` 
and `x[i,2] = b_i`. For a given matrix input `x` the function `g` 
must produce a scalar, for example `g(x) = @views mean(x[:,1])^2 - mean(x[:,2].^2)`.
"""
function jackknife_full(g::Function, x::AbstractMatrix{<:Number})
    gis = leaveoneout(g,x)
    return estimate(g,x,gis), std_error(g,x,gis)
end

jackknife_full(g::Function, x::AbstractVector{<:Number}) = jackknife_full(g, reshape(x, (:,1)))
jackknife_full(g::Function, xs::AbstractVector{<:Number}...) = jackknife_full(g, hcat(xs...))




"""
    jackknife(g::Function, x::AbstractMatrix) -> jstd

Jackknife standard error `jstd` of `g(<a>,<b>,...)`.

Columns of `x` are time series of random variables, i.e. `x[i,1] = a_i` 
and `x[i,2] = b_i`. For a given matrix input `x` the function `g` 
must produce a scalar, for example `g(x) = @views mean(x[:,1])^2 - mean(x[:,2].^2)`.
"""
function jackknife(g::Function, x::AbstractMatrix{<:Number})
    gis = leaveoneout(g,x)
    return std_error(g,x,gis)
end

jackknife(g::Function, x::AbstractVector{<:Number}) = jackknife(g, reshape(x, (:,1)))
jackknife(g::Function, xs::AbstractVector{<:Number}...) = jackknife(g, hcat(xs...))




"""
    leaveoneout(g::Function, x::AbstractMatrix)

Estimate `g(<a>,<b>,...)` systematically omitting each time index one 
at a time. The result is a vector with the resulting jackknife block 
values `g_i(x_[])`.

Columns of `x` are time series of random variables, i.e. `x[i,1] = a_i` 
and `x[i,2] = b_i`. For a given matrix input `x` the function `g` 
must produce a scalar, for example `g(x) = @views mean(x[:,1])^2 - mean(x[:,2].^2)`.
"""
function leaveoneout(g::Function, x::AbstractMatrix{<:Number})
    size(x,1) > 1 || throw(ArgumentError("The sample must have size > 1"))
    return @views [g(circshift(x, -i)[2:end,..]) for i in 0:size(x,1)-1]
end





"""
    var(g::Function, x::AbstractMatrix)

Compute the jackknife estimate of the variance of `g(<a>,<b>,...)`, where `g` is given as a
function that computes a point estimate (scalar) when passed a matrix `x`. Columns of `x` 
are time series of the random variables.

For more details, see also [`leaveoneout](@ref).
"""
function var(g::Function, x::AbstractMatrix{<:Number}, gis::AbstractVector{<:Real})
    n = size(x,1)
    return var(gis) * (n - 1)^2 / n # Eq. (3.35) in QMC Methods book
end
var(g::Function, x::AbstractVector{<:Number}) = var(g, reshape(x, (:,1)))
var(g::Function, x::AbstractMatrix{<:Number}) = var(g,x,leaveoneout(g, x))
var(g::Function, x::AbstractMatrix{<:Number}, gis::AbstractVector{<:Complex}) = var(g,x,real(gis)) + var(g,x,imag(gis))





"""
    std_error(g::Function, x::AbstractMatrix)

Compute the jackknife estimate of the one sigma error of `g(<a>,<b>,...)`, where `g` is given as a
function that computes a point estimate (scalar) when passed a matrix `x`. Columns of `x` 
are time series of the random variables.

For more details, see also [`leaveoneout](@ref).
"""
std_error(g::Function, x::AbstractMatrix{<:Number}, gis::AbstractVector{<:Real}) = sqrt(var(g,x, gis))
std_error(g::Function, x::AbstractMatrix{<:Number}, gis::AbstractVector{<:Complex}) = sqrt(std_error(g,x,real(gis))^2 + std_error(g,x,imag(gis))^2)
std_error(g::Function, x::AbstractVector{<:Number}) = std_error(g, reshape(x, (:,1)))
std_error(g::Function, x::AbstractMatrix{<:Number}) = std_error(g,x,leaveoneout(g,x))





"""
    bias(g::Function, x::AbstractMatrix)

Compute the jackknife estimate of the bias of `g(<a>,<b>,...)`, which computes a point 
estimate when passed a matrix `x`. Columns of `x` are time series of the random variables.

For more details, see also [`leaveoneout](@ref).
"""
function bias(g::Function, x::AbstractMatrix{<:Number}, gis::AbstractVector{<:Number}=leaveoneout(g, x))
    return (size(x,1) - 1) * (mean(gis) - g(x)) # Basically Eq. (3.33)
end
bias(g::Function, x::AbstractVector{<:Number}) = bias(g, reshape(x, (:,1)))






"""
    estimate(g::Function, x)

Compute the bias-corrected jackknife estimate of `g(<a>,<b>,...)`, which computes a 
point estimate when passed a matrix `x`. Columns of `x` are time series of the random variables.

For more details, see also [`leaveoneout](@ref).
"""
function estimate(g::Function, x::AbstractMatrix{<:Number}, gis::AbstractVector{<:Number}=leaveoneout(g, x))
    n = size(x,1)
    return n * g(x) - (n - 1) * mean(gis) # Eq. (3.34) in QMC Methods book
end
estimate(g::Function, x::AbstractVector{<:Number}) = estimate(g, reshape(x, (:,1)))




end # module


# TODO: Prebinning + Jackknife