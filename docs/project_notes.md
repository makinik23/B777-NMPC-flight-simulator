# Project Notes - B777 NMPC Flight Simulator

## Stage 1 - Project Initialisation

### Goal

Create the initial project structure, prepare the documentation skeleton and start maintaining the engineering-thesis LaTeX sources alongside the implementation.

### Completed

- Created project directories consistent with the project manifest.
- Prepared the initial MATLAB startup files.
- Prepared the technical documentation skeleton.
- Prepared the LaTeX thesis skeleton.

### Project Decisions

- The aircraft model is an educational **B777-like** model, not an exact or certified Boeing 777 model.
- The nonlinear 6-DOF plant comes first, followed by trim and validation, and only then by NMPC development.
- The LaTeX documentation is developed in parallel with implementation rather than written only at the end.

### Next Step

Define reference frames, units, sign conventions, and the initial lists of model states and inputs.
