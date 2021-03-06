############################
### Easy parametrization ###
############################

function action(phi, prm) where {T}

    # For type stability initialize to correct type
    # https://www.juliabloggers.com/writing-type-stable-julia-code/
    act = zero(eltype(phi))

    Nx = size(phi,1)
    Ny = size(phi,2)
    for i in 1:Nx, j in 1:Ny
        iu = mod1(i+1, Nx)
        ju = mod1(j+1, Ny)
        act = act + (phi[i,j]-phi[iu,j])^2 + (phi[i,j]-phi[i,ju])^2 +
            prm.msq*phi[i,j]^2 + prm.lam*phi[i,j]^4
    end

    return act/2
end

# Force is computed in place for performance
function force!(frc, phi, prm) 

    Nx = size(phi,1)
    Ny = size(phi,2)
    for i in 1:Nx, j in 1:Ny
        iu = mod1(i+1, Nx)
        ju = mod1(j+1, Ny)
        id = mod1(i-1, Nx)
        jd = mod1(j-1, Ny)
        
        frc[i,j] = phi[iu,j] + phi[id,j] + phi[i,ju] + phi[i,jd] -
            (prm.msq+4)*phi[i,j] - 2*prm.lam*phi[i,j]^3
    end

    return nothing
end

# cf_tape has recorded the operations to do the derivative
# https://github.com/JuliaDiff/ReverseDiff.jl/blob/master/examples/gradient.jl
force!(frc, phi, cf_tape::ReverseDiff.CompiledTape) where {T} =  ReverseDiff.gradient!(frc, cf_tape, phi)



############################
### Alt. parametrization ###
############################

function action(phi, prm::LattParmB) where {T}

    # For type stability initialize to correct type
    # https://www.juliabloggers.com/writing-type-stable-julia-code/
    act = zero(eltype(phi))

    Nx = size(phi,1)
    Ny = size(phi,2)
    for i in 1:Nx, j in 1:Ny
        iu = mod1(i+1, Nx)
        ju = mod1(j+1, Ny)
        act = act - prm.beta * phi[i,j] * (phi[iu,j] + phi[i,ju]) +
                (1 - 2 * prm.lambda) * phi[i,j]^2 + prm.lambda * phi[i,j]^4
    end


    return act
end

# Force is computed in place for performance
function force!(frc, phi, prm::LattParmB) 

    Nx = size(phi,1)
    Ny = size(phi,2)
    for i in 1:Nx, j in 1:Ny
        iu = mod1(i+1, Nx)
        ju = mod1(j+1, Ny)
        id = mod1(i-1, Nx)
        jd = mod1(j-1, Ny)
        
        frc[i,j] = prm.beta * (phi[iu,j] + phi[id,j] + phi[i,ju] + phi[i,jd]) + 
                    2 * phi[i,j] * (2 * prm.lambda * (1 - phi[i,j]^2) - 1)
    end

    return nothing
end


# TODO: needs checking...
function he_force(phi, prm, t)
    L = prm.iL[1]
    frc0 = similar(phi)
    frc = similar(phi)
    expmat = similar(phi)
    force!(frc0, phi, prm)

    function trururu(prm, x, xprime, t)
        L = prm.iL[1]
        res = zeros(ComplexF64, prm.iL)
        for k1 in 1:L, k2 in 1:L
            p = (2 * pi / L) .* (k1 - 1, k2 - 1)
            p2 = Scalar2D.hat_p2(k1-1, k2-1, L)
            res[k1, k2] = exp(p2*t) * exp(im * sum( p .* (xprime .- x)))
        end
        return real.(sum(res))
    end

    for x1 in 1:L, x2 in 1:L
        for xp1 in 1:L, xp2 in 2:L
            expmat[xp1, xp2] = trururu(prm, (x1, x2), (xp1, xp2), t)
        end
        frc[x1, x2] = sum(frc0 .* expmat)
    end
    
    return 1/L^2 .* frc
end
