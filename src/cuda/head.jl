abstract type AbstractSimGPU <:AbstractSim end
abstract type MeshGPU <: Mesh end
abstract type DriverGPU end
abstract type MicroEnergyGPU end

struct FDMeshGPU{T <: AbstractFloat} <: MeshGPU
  dx::T
  dy::T
  dz::T
  nx::Int64
  ny::Int64
  nz::Int64
  nxyz::Int64
  xperiodic::Bool
  yperiodic::Bool
  zperiodic::Bool
  volume::T
end

mutable struct MicroSimGPU{T<:AbstractFloat} <:AbstractSimGPU
  mesh::FDMeshGPU
  driver::DriverGPU
  saver::DataSaver
  spin::CuArray{T, 1}
  prespin::CuArray{T, 1}
  field::CuArray{T, 1}
  energy::CuArray{T, 1}
  Ms::CuArray{T, 1}
  total_energy::T
  nxyz::Int64
  blocks::Int64
  threads::Int64
  name::String
  interactions::Array{Any, 1}
  save_data::Bool
  MicroSimGPU{T}() where {T<:AbstractFloat} = new()
end


mutable struct ExchangeGPU{T<:AbstractFloat} <: MicroEnergyGPU
   A::CuArray{T, 1}
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct Vector_ExchangeGPU{T<:AbstractFloat} <: MicroEnergyGPU
   A::CuArray{T, 1}
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct ExchangeRKKYGPU{T<:AbstractFloat} <: MicroEnergyGPU
   sigma::T
   Delta::T
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct BulkDMIGPU{T<:AbstractFloat} <: MicroEnergyGPU
   Dx::T
   Dy::T
   Dz::T
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct InterfacialDMIGPU{T<:AbstractFloat} <: MicroEnergyGPU
   D::T
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct SpatialBulkDMIGPU{T<:AbstractFloat} <: MicroEnergyGPU
   D::CuArray{T, 1}
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct ZeemanGPU{T<:AbstractFloat} <: MicroEnergyGPU
   field::Array{T, 1}
   energy::Array{T, 1}
   cufield::CuArray{T, 1}
   total_energy::T
   name::String
end

mutable struct TimeZeemanGPU{T<:AbstractFloat} <: MicroEnergyGPU
   time_fun::Function
   init_field::CuArray{T, 1}
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct AnisotropyGPU{T<:AbstractFloat} <: MicroEnergyGPU
   Ku::CuArray{T, 1}
   axis::Tuple
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end

mutable struct CubicAnisotropyGPU{T<:AbstractFloat} <: MicroEnergyGPU
   Kc::T
   field::Array{T, 1}
   energy::Array{T, 1}
   total_energy::T
   name::String
end
