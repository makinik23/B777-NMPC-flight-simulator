# B777 NMPC Flight Simulator

Nonlinear flight dynamics simulator for Boeing 777-like plane and Nonlinear Model Predictive Control w MATLAB/Simulink.

## Structure

- `data/` — geometry, mass, inertia, aerodynamics, thrust, flight configurations.
- `plant/` — nonlinear 6DOF.
- `nmpc/` — state, outputs, cost i constraints for NMPC.
- `guidance/` — MCP, mode manager, LNAV/VNAV/ILS i reference generators.
- `validation/` — trimming, simulation and autopilot tests.
- `models/` — modele Simulinka `.slx`.
- `plots/` — output graphs..
- `docs/` — documentation.
