using WriteVTK
using NPZ

function save(sim::MicroSimGPU, fname::String;vtk::Bool = false,npy::Bool = false)
  if vtk
    if !isdir(vtk_folder)
      mkdir(vtk_folder)
    end
    save_vtk(sim, joinpath(vtk_folder, fname))
  end
  if npy
    save_npy(sim,fname)
  end
end

function save_npy(sim::MicroSimGPU,name::String)
  name = @sprintf("%s.npy", name)
  mesh = sim.mesh
  nxyz = mesh.nx*mesh.ny*mesh.nz
  spin = zeros(3*nxyz)
  copy!(spin, sim.spin)
  npzwrite(name, spin)
end

function save_vtk(sim::AbstractSimGPU, fname::String; fields::Array{String, 1} = String[])
  mesh = sim.mesh
  nx, ny, nz = mesh.nx, mesh.ny, mesh.nz
  xyz = zeros(Float32, 3, nx+1, ny+1, nz+1)
  dx, dy, dz=mesh.dx, mesh.dy, mesh.dz
  if isa(mesh, TriangularMesh)
      for k = 1:nz+1, j = 1:ny+1, i = 1:nx+1
        xyz[1, i, j, k] = (i-0.5)*dx + (j-1)*dx/2
        xyz[2, i, j, k] = (j-0.5)*dy
        xyz[3, i, j, k] = (k-0.5)*dz
      end
  else
    for k = 1:nz+1, j = 1:ny+1, i = 1:nx+1
      xyz[1, i, j, k] = (i-0.5)*dx
      xyz[2, i, j, k] = (j-0.5)*dy
      xyz[3, i, j, k] = (k-0.5)*dz
    end
  end
  vtk = vtk_grid(fname, xyz)
  T = _cuda_using_double.x ? Float64 : Float32
  xyz = zeros(T, 3*sim.nxyz)
  copyto!(xyz, sim.spin)
  b = reshape(xyz, (3, nx, ny, nz))
  vtk_cell_data(vtk, b , "m")

  if length(fields) > 0
    fields = Set(fields)
    for i in sim.interactions
      if i.name in fields
        b = reshape(i.field, (3, nx, ny, nz))
        vtk_cell_data(vtk, b, i.name)
      end
    end
  end
  vtk_save(vtk)
end
