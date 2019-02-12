# Thin wrapper type, mainly for dispatch
struct FullBinner{T, A <: AbstractVector{T}} <: AbstractVector{T}
    x::A
end

@forward FullBinner.x (Base.length, Base.size, Base.lastindex, Base.ndims, Base.iterate,
                        Base.getindex, Base.setindex!, Base.view, Base.axes,
                        Base.push!, Base.append!, Base.resize!, Base.sizehint!, Base.empty!,
                        Base.isempty)


FullBinner(::Type{T} = Float64) where T = FullBinner(Vector{T}(undef, 0))




#####
# Calculation of error coefficient (function) R. (Ch. 3.4 in QMC book)
#####
"""
Groups datapoints in bins of fixed binsize and returns error coefficient R. (Eq. 3.20)
"""
function R_value(X::AbstractVector{T}, binsize::Int) where T<:Real
    N = length(X)
    n_bins = div(N,binsize)
    lastbs = rem(N,binsize)

    @views blockmeans = vec(mean(reshape(X[1:n_bins*binsize], (binsize,n_bins)), dims=1))
    # if lastbs != 0
    #     vcat(blockmeans, mean(X[n_bins*binsize+1:end]))
    #     n_bins += 1
    # end

    blocksigma2 = 1/(n_bins-1)*sum((blockmeans .- mean(X)).^2)
    return binsize * blocksigma2 / var(X)
end


_R2std_error(X, Rvalue) = sqrt(Rvalue*var(X)/length(X))


"""
Groups datapoints in bins of varying size `bs`.
Returns the used binsizes `bss`, the error coefficient function values `R(bss)` (Eq. 3.20), and 
the cumulative error coefficients `<R>(bss)`. The function should feature a plateau, 
i.e. `R(bs_p) ~ R(bs)` for `bs >= bs_p`. (Fig. 3.3)

Optional keyword `min_nbins`. Only bin sizes used that lead to at least `min_nbins` bins.
"""
function R_function(X::AbstractVector{T}; min_nbins=32) where T<:Real
    max_binsize = floor(Int, length(X)/min_nbins)
    binsizes = 1:max_binsize

    R = Vector{Float64}(undef, length(binsizes))
    @inbounds for bs in binsizes
        R[bs] = R_value(X, bs)
    end

    means = @views mean.([R[1:i] for i in 1:max_binsize])
    return binsizes, R, means
end