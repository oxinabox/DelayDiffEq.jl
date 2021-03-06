using DelayDiffEq, DiffEqProblemLibrary, DiffEqDevTools,
      DiffEqCallbacks, Base.Test

prob = prob_dde_1delay_scalar_notinplace
alg = MethodOfSteps(Tsit5(); constrained=false)

# continuous callback

cb = ContinuousCallback((t, u, integrator) -> t - 2.60, # Event when event_f(t,u,k) == 0
                        integrator -> (integrator.u = - integrator.u))

sol1 = solve(prob, alg, callback=cb)

sol2 = solve(prob, alg, callback=cb, dtmax=0.01)

sol3 = appxtrue(sol1, sol2)

@test sol3.errors[:L2] < 4.1e-3
@test sol3.errors[:L∞] < 1.3e-2

# discrete callback

cb = AutoAbstol()

sol1 = solve(prob, alg, callback=cb)

sol2 = solve(prob, alg, callback=cb, dtmax=0.01)

sol3 = appxtrue(sol1, sol2)

@test sol3.errors[:L2] < 1.4e-3
@test sol3.errors[:L∞] < 4.1e-3
