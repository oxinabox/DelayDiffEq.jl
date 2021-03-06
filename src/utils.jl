"""
    fsal_typeof(integrator::ODEIntegrator)

Return type of FSAL of `integrator`.
"""
function fsal_typeof(integrator::ODEIntegrator{<:OrdinaryDiffEq.OrdinaryDiffEqAlgorithm,
                                               uType,tType,tTypeNoUnits,tdirType,ksEltype,
                                               SolType,F,ProgressType,CacheType,O,
                                               FSALType}) where {uType,tType,tTypeNoUnits,
                                                                 tdirType,ksEltype,SolType,
                                                                 F,ProgressType,CacheType,O,
                                                                 FSALType}
    return FSALType
end

"""
    build_linked_cache(cache, alg, u, uprev, uprev2, f, t, dt)

Create cache for algorithm `alg` from existing cache `cache` with updated `u`, `uprev`,
`uprev2`, `f`, `t`, and `dt`.
"""
@generated function build_linked_cache(cache, alg, u, uprev, uprev2, f, t, dt)
    assignments = [assign_expr(Val{name}(), fieldtype(cache, name), cache)
                   for name in fieldnames(cache) if name ∉ [:u, :uprev, :uprev2, :t, :dt]]

    :($(assignments...); $(DiffEqBase.parameterless_type(cache))($(fieldnames(cache)...)))
end

"""
    assign_expr(::Val{name}, ::Type{T}, ::Type{cache})

Create expression that extracts field `name` of type `T` from cache of type `cache`
to variable `name`.

Hereby u, uprev, uprev2, and function f are updated, if required.
"""
assign_expr(::Val{name}, ::Type, ::Type) where {name} =
    :($name = getfield(cache, $(Meta.quot(name))))

# update matrix exponential
assign_expr(::Val{:expA}, ::Type, ::Type) =
    :(A = f.f1; expA = expm(A*dt))
assign_expr(::Val{:phi1}, ::Type, ::Type{<:OrdinaryDiffEq.NorsettEulerCache}) =
    :(phi1 = ((expA-I)/A))

# update derivative wrappers
assign_expr(::Val{name}, ::Type{<:DiffEqDiffTools.TimeDerivativeWrapper}, ::Type) where name =
    :($name = DiffEqDiffTools.TimeDerivativeWrapper(f, u))
assign_expr(::Val{name}, ::Type{<:DiffEqDiffTools.UDerivativeWrapper}, ::Type) where name =
    :($name = DiffEqDiffTools.UDerivativeWrapper(f, t))
assign_expr(::Val{name}, ::Type{<:DiffEqDiffTools.TimeGradientWrapper}, ::Type) where name =
    :($name = DiffEqDiffTools.TimeGradientWrapper(
        f,uprev))
assign_expr(::Val{name}, ::Type{<:DiffEqDiffTools.UJacobianWrapper}, ::Type) where name =
    :($name = DiffEqDiffTools.UJacobianWrapper(
        f,t))

# create new config of Jacobian
assign_expr(::Val{name}, ::Type{ForwardDiff.JacobianConfig{T,V,N,D}},
            ::Type) where {name,T,V,N,D} =
                :($name = ForwardDiff.JacobianConfig(uf, du1, uprev,
                                                     ForwardDiff.Chunk{$N}()))

# update implicit RHS
assign_expr(::Val{name}, ::Type{<:OrdinaryDiffEq.ImplicitRHS}, ::Type) where name =
    :($name = OrdinaryDiffEq.ImplicitRHS(f, cache.tmp, t, t, t, cache.dual_cache))
assign_expr(::Val{name}, ::Type{<:OrdinaryDiffEq.ImplicitRHS_Scalar}, ::Type) where name =
    :($name = OrdinaryDiffEq.ImplicitRHS_Scalar(f, zero(u), t, t, t))
assign_expr(::Val{name}, ::Type{<:OrdinaryDiffEq.RHS_IIF}, ::Type) where name =
    :($name = OrdinaryDiffEq.RHS_IIF(f, cache.tmp, t, t, cache.tmp, cache.dual_cache))
assign_expr(::Val{name}, ::Type{<:OrdinaryDiffEq.RHS_IIF_Scalar}, ::Type) where name =
    :($name = OrdinaryDiffEq.RHS_IIF_Scalar(f, zero(u), t, t,
                                            getfield(cache, $(Meta.quot(name))).a))

# create new NLsolve differentiable function
assign_expr(::Val{name}, ::Type{<:NLsolve.DifferentiableMultivariateFunction},
            ::Type{<:OrdinaryDiffEq.OrdinaryDiffEqMutableCache}) where name =
                :($name = alg.nlsolve(Val{:init},rhs,u))
assign_expr(::Val{name}, ::Type{<:NLsolve.DifferentiableMultivariateFunction},
            ::Type{<:OrdinaryDiffEq.OrdinaryDiffEqConstantCache}) where name =
                :($name = alg.nlsolve(Val{:init},rhs,uhold))
