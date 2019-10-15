#implement the  Runge-Kutta method with adaptive stepsize using Dormand–Prince pair
#https://en.wikipedia.org/wiki/List_of_Runge%E2%80%93Kutta_methods#Dormand%E2%80%93Prince

mutable struct DormandPrince <: Integrator
    tol::Float64
    t::Float64
    step::Float64
    step_next::Float64
    facmax::Float64
    facmin::Float64
    safety::Float64
    nsteps::Int64
    nfevals::Int64
    spin::Array{Float64, 1}
    dm_dt::Array{Float64, 1}
    k1::Array{Float64, 1}
    k2::Array{Float64, 1}
    k3::Array{Float64, 1}
    k4::Array{Float64, 1}
    k5::Array{Float64, 1}
    k6::Array{Float64, 1}
    k7::Array{Float64, 1}
    rhs_fun::Function
    succeed::Bool
end

function DormandPrince(nxyz::Int64, rhs_fun, tol::Float64)
  dm_dt = zeros(Float64,3*nxyz)
  spin = zeros(Float64,3*nxyz)
  k1 = zeros(Float64, 3*nxyz)
  k2 = zeros(Float64, 3*nxyz)
  k3 = zeros(Float64, 3*nxyz)
  k4 = zeros(Float64, 3*nxyz)
  k5 = zeros(Float64, 3*nxyz)
  k6 = zeros(Float64, 3*nxyz)
  k7 = zeros(Float64, 3*nxyz)
  facmax = 5.0
  facmin = 0.2
  safety = 0.824
  return DormandPrince(tol, 0.0, 0, 0, facmax, facmin, safety, 0, 0, spin, dm_dt,
                k1, k2, k3, k4, k5, k6, k7, rhs_fun, false)
end

function dopri5_step_inner(sim::AbstractSim, step::Float64, t::Float64)
  a = (1/5, 3/10, 4/5, 8/9, 1.0, 1.0)
  b = (1/5, 3/40, 9/40, 44/45, -56/15, 32/9)
  c = (19372/6561, -25360/2187, 64448/6561, -212/729)
  d = (9017/3168, -355/33, 46732/5247, 49/176, -5103/18656)
  v = (35/384, 0, 500/1113, 125/192, -2187/6784, 11/84)
  w = (71/57600, 0, -71/16695, 71/1920, -17253/339200, 22/525, -1/40)
  ode = sim.driver.ode
  rhs = ode.rhs_fun

  k1,k2,k3,k4,k5,k6,k7 = ode.k1, ode.k2, ode.k3, ode.k4, ode.k5, ode.k6, ode.k7

  y_next = sim.spin
  y_current = sim.prespin
  y_next .= y_current
  ode.rhs_fun(sim, k1, y_next, t) #compute k1, TODO: copy k7 directly to k1

  y_next .= y_current .+ b[1].*k1.*step
  ode.rhs_fun(sim, k2, y_next, t + a[1]*step) #k2

  y_next .= y_current .+ (b[2].*k1 .+ b[3].*k2).*step
  ode.rhs_fun(sim, k3, y_next, t + a[2]*step) #k3

  y_next .= y_current .+ (b[4].*k1 .+ b[5].*k2 .+ b[6].*k3).*step
  ode.rhs_fun(sim, k4, y_next, t + a[3]*step) #k4

  y_next .= y_current .+ (c[1].*k1 .+ c[2].*k2 + c[3].*k3 .+ c[4].*k4).*step
  ode.rhs_fun(sim, k5, y_next, t + a[4]*step) #k5

  y_next .= y_current .+ (d[1].*k1 .+ d[2].*k2 .+ d[3].*k3 .+ d[4].*k4 + d[5].*k5).*step
  ode.rhs_fun(sim, k6, y_next, t + a[5]*step) #k6

  y_next .= y_current .+ (v[1].*k1 .+ v[2].*k2 .+ v[3].*k3 .+ v[4].*k4 .+ v[5].*k5 .+ v[6].*k6) .* step
  normalise(y_next, sim.nxyz) #if we want to copy k7 to k1, we should normalise it here.
  ode.rhs_fun(sim, k7, y_next, t + a[6]*step) #k7

  ode.nfevals += 7
  error = ode.spin #we make use of ode.spin to store the error temporary
  error .= (w[1].*k1 + w[2].*k2 .+ w[3].*k3 .+ w[4].*k4 .+ w[5].*k5 + w[6].*k6 + w[7].*k7).*step

  max_error =  maximum(abs.(error)) + eps()

  return max_error
end


function compute_init_step_DP(sim::AbstractSim, dt::Float64)
  abs_step = dt
  abs_step_tmp = dt
  integrator = sim.driver.ode
  integrator.rhs_fun(sim, integrator.dm_dt, sim.spin, integrator.t)
  r_step = maximum(abs.(integrator.dm_dt)/(integrator.safety*integrator.tol^0.2))
  integrator.nfevals += 1
  #FIXME: how to obtain a reasonable init step?
  if abs_step*r_step > 0.001
    abs_step_tmp = 0.001/r_step
  end
  return min(abs_step, abs_step_tmp)
end

function advance_step(sim::AbstractSim, integrator::DormandPrince)

    t = integrator.t

    sim.prespin .= sim.spin

    if integrator.step_next <= 0
        integrator.step_next = compute_init_step_DP(sim, 1.0)
    end

    step_next = integrator.step_next

    while true
        max_error = dopri5_step_inner(sim, step_next, t)/integrator.tol

        integrator.succeed = (max_error <= 1)

        if integrator.succeed
            integrator.nsteps += 1
            integrator.step = step_next
            integrator.t += integrator.step
            factor =  integrator.safety*(1.0/max_error)^0.2
            integrator.step_next = step_next*min(integrator.facmax, max(integrator.facmin, factor))
            break
        else
            factor =  integrator.safety*(1.0/max_error)^0.25
            step_next = step_next*min(integrator.facmax, max(integrator.facmin, factor))
        end
    end
    #normalise(sim.spin, sim.nxyz)
end