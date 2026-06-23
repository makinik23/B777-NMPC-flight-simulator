# Aircraft Geometry and Mass-Inertia Data

## Goal

This feature defines the first reusable aircraft data modules for the B777-like
nonlinear flight-dynamics simulator:

- `data/b777_geometry.m`
- `data/b777_mass_inertia.m`
- `tests/features/test_aircraft_data.m`

The model is educational and engineering-oriented. It is not a certified,
proprietary or exact Boeing 777 model.

## Public Reference Values

| Quantity | Value | Use |
|---|---:|---|
| Variant | B777-300ER-like | Reference configuration |
| Length | 73.90 m | Fuselage and inertia scaling |
| Wingspan | 64.80 m | Wing geometry and inertia scaling |
| Overall height | 18.50 m | Basic aircraft dimensions |
| Wing area | 436.80 m^2 | Aerodynamic reference area |
| MTOW | 351530 kg | Mass envelope and checks |
| Engine model | GE90-115B | Propulsion reference |
| Static thrust per engine | 512 kN | First propulsion model |
| Mean aerodynamic chord | 7.074 m | Moment coefficient scaling |
| Standard gravity | 9.80665 m/s^2 | Fixed project default until an environment model is introduced |

## Derived Values

| Quantity | Formula | Value |
|---|---|---:|
| Wing aspect ratio | `b^2 / S` | 9.612 |
| Geometric mean chord | `S / b` | 6.741 m |
| Total static thrust | `2 * T_engine` | 1024 kN |
| Static T/W at MTOW | `T_total / (MTOW*g0)` | 0.297 |

## Estimated Values

The following values are deliberately treated as first-cut estimates:

- inertia tensor,
- engine position relative to the center of gravity,
- tail arms,
- wing taper ratio,
- detailed tail geometry.

These values are good enough to start integrating the 6-DOF plant, but they
should be revisited after trim, modal response and validation tests.

## Modelling Decision

`b777_mass_inertia.m` estimates the inertia tensor from effective radii of
gyration. The matrix follows the convention used in the mathematical model:

```text
J = [ Ixx   0   -Ixz
       0   Iyy   0
     -Ixz   0   Izz ]
```

For the first cut, `Ixz = 0`. This keeps the model simple while the rest of
the 6-DOF equations are being assembled.

Gravity-dependent force quantities are not stored as fixed mass properties.
For now the project uses constant standard gravity from `b777_constants`:

```matlab
mass = b777_mass_inertia();
forces = mass.forces(mass.standard_gravity_mps2);
```

## Check

In MATLAB:

```matlab
startup
results = runtests("tests/features/test_aircraft_data.m");
assertSuccess(results)
```

Alternative explicit path form:

```matlab
run('tests/features/test_aircraft_data.m')
```

Expected final message:

```text
Feature test passed: aircraft data are defined consistently.
```
