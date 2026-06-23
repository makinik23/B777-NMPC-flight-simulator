# Model Assumptions

This document defines the basic modelling assumptions used in the B777-like nonlinear flight dynamics simulator with an NMPC-based autopilot.

The purpose of this project is educational and engineering-oriented. The aircraft is treated as a Boeing 777-like wide-body transport aircraft, but the model is not intended to represent a certified, proprietary or exact Boeing 777 simulation model.

---

## 1. General Assumptions

1. The aircraft is modelled as a rigid body.
2. The aircraft motion is described using nonlinear six-degree-of-freedom equations.
3. The Earth is initially approximated as flat and non-rotating.
4. The navigation frame is a local North-East-Down frame.
5. The atmosphere is modelled using the International Standard Atmosphere model.
6. Aerodynamic forces and moments are represented using coefficient-based models.
7. Control surfaces and engines include saturation and rate limits.
8. Engine thrust dynamics are represented using a simplified first-order model.
9. The model is designed for control design, simulation and educational analysis.
10. The model is not intended for certification-level flight simulation.

---

## 2. Units

The project uses SI units.

| Quantity         |   Unit |
| ---------------- | -----: |
| Length           |      m |
| Time             |      s |
| Mass             |     kg |
| Force            |      N |
| Moment           |    N m |
| Angle            |    rad |
| Angle for plots  |    deg |
| Linear velocity  |    m/s |
| Angular velocity |  rad/s |
| Density          | kg/m^3 |
| Pressure         |     Pa |
| Power            |      W |

All internal computations should be performed in SI units. Degrees may be used only for plots, tables and user-facing interpretation.

---

## 3. Reference Frames

### 3.1 Navigation Frame

The navigation frame is a local North-East-Down frame, denoted as NED.

Its axes are defined as follows:

* `x_n` points North,
* `y_n` points East,
* `z_n` points Down.

The aircraft position in this frame is described by:

```text
r_n = [N, E, D]^T
```

where:

* `N` is the north position,
* `E` is the east position,
* `D` is the down position.

The altitude is defined as:

```text
h = -D
```

Therefore, increasing altitude corresponds to decreasing `D`.

### 3.2 Body Frame

The body frame is attached to the aircraft and is denoted by the subscript `b`.

Its axes are defined as follows:

* `x_b` points forward through the aircraft nose,
* `y_b` points through the right wing,
* `z_b` points downward.

This convention gives a right-handed coordinate system.

The body-axis velocity vector is:

```text
V_b = [u, v, w]^T
```

where:

* `u` is the forward velocity component,
* `v` is the right velocity component,
* `w` is the downward velocity component.

### 3.3 Wind Frame

The wind frame is related to the air-relative velocity vector.

The `x_w` axis is aligned with the airspeed vector. In this convention:

* drag acts along `-x_w`,
* lift acts approximately along `-z_w`,
* side force acts along `y_w`.

The wind frame is used mainly for defining aerodynamic forces and aerodynamic angles.

---

## 4. Velocity, Angles and Angular Rates

The airspeed is defined as:

```text
V = sqrt(u^2 + v^2 + w^2)
```

The angle of attack is defined as:

```text
alpha = atan2(w, u)
```

The sideslip angle is defined as:

```text
beta = asin(v / V)
```

The body angular velocity vector is:

```text
omega_b = [p, q, r]^T
```

where:

* `p` is the roll rate about `+x_b`,
* `q` is the pitch rate about `+y_b`,
* `r` is the yaw rate about `+z_b`.

The Euler angle vector is:

```text
eta = [phi, theta, psi]^T
```

where:

* `phi` is the roll angle,
* `theta` is the pitch angle,
* `psi` is the yaw angle or heading angle.

---

## 5. Moment Sign Convention

The total moment vector in the body frame is:

```text
M_b = [L, M, N]^T
```

where:

* `L` is the rolling moment,
* `M` is the pitching moment,
* `N` is the yawing moment.

The adopted sign convention is:

* positive `L` produces positive roll rate `p`,
* positive `M` produces positive pitch rate `q`,
* positive `N` produces positive yaw rate `r`.

With the adopted body frame, positive roll means that the right wing moves downward.

Positive pitching moment corresponds to a nose-up rotation.

---

## 6. Force Convention

The total force vector in the body frame is:

```text
F_b = [X, Y, Z]^T
```

where:

* `X` is the force component along the body `x_b` axis,
* `Y` is the force component along the body `y_b` axis,
* `Z` is the force component along the body `z_b` axis.

Since `z_b` points downward, a positive `Z` force acts downward. Lift usually contributes a negative component to `Z` in normal flight conditions.

The total force is composed of:

```text
F_b = F_aero,b + F_eng,b + F_g,b
```

where:

* `F_aero,b` is the aerodynamic force,
* `F_eng,b` is the engine force,
* `F_g,b` is the gravity force expressed in the body frame.

---

## 7. Control Input Convention

The command input vector is:

```text
u_cmd = [
    delta_e_cmd,
    delta_a_cmd,
    delta_r_cmd,
    tau_1_cmd,
    tau_2_cmd
]^T
```

where:

* `delta_e_cmd` is the commanded elevator deflection,
* `delta_a_cmd` is the commanded effective aileron deflection,
* `delta_r_cmd` is the commanded effective rudder deflection,
* `tau_1_cmd` is the left engine throttle command,
* `tau_2_cmd` is the right engine throttle command.

Throttle commands satisfy:

```text
0 <= tau_i <= 1
```

where `tau_i = 0` represents idle or minimum thrust and `tau_i = 1` represents maximum available thrust.

### 7.1 Elevator

Positive elevator deflection means trailing edge down.

With this physical convention, positive elevator deflection usually produces a negative pitching moment:

```text
C_m_delta_e < 0
```

This means that a positive elevator command tends to pitch the aircraft nose down, depending on the adopted aerodynamic coefficient convention.

### 7.2 Aileron

Positive effective aileron deflection is defined as:

```text
left aileron down, right aileron up
```

It should produce a positive rolling moment:

```text
C_l_delta_a > 0
```

Therefore, a positive effective aileron command should result in positive roll acceleration.

### 7.3 Rudder

Positive effective rudder deflection is defined as a rudder command that produces a positive yawing moment:

```text
C_n_delta_r > 0
```

Therefore, a positive rudder command should result in positive yaw acceleration.

---

## 8. Full 6-DOF State Vector

The full nonlinear plant state vector is defined as:

```text
x_6dof = [
    N,
    E,
    D,
    u,
    v,
    w,
    phi,
    theta,
    psi,
    p,
    q,
    r,
    T1,
    T2,
    delta_e,
    delta_a,
    delta_r
]^T
```

where:

| Symbol                | Meaning                             |
| --------------------- | ----------------------------------- |
| `N`, `E`, `D`         | position in the local NED frame     |
| `u`, `v`, `w`         | body-axis velocity components       |
| `phi`, `theta`, `psi` | Euler angles                        |
| `p`, `q`, `r`         | body angular rates                  |
| `T1`, `T2`            | actual engine thrust values         |
| `delta_e`             | actual elevator deflection          |
| `delta_a`             | actual effective aileron deflection |
| `delta_r`             | actual effective rudder deflection  |

The actuator and engine states are included because control surfaces and engines are not assumed to react instantaneously.

---

## 9. Commanded Inputs and Actual Actuator States

The commanded inputs are not applied directly to the rigid-body equations. Instead, they are passed through actuator and engine dynamics.

For example, the elevator command `delta_e_cmd` produces the actual elevator deflection `delta_e` after applying:

* deflection limits,
* rate limits,
* actuator dynamics.

Similarly, the throttle commands `tau_1_cmd` and `tau_2_cmd` produce the actual thrust values `T1` and `T2` after applying:

* throttle limits,
* engine thrust limits,
* simplified engine spool dynamics.

This separation is important for NMPC because the controller must respect realistic actuator constraints.

---

## 10. Reduced NMPC Models

The first NMPC implementation will be divided into two parts:

1. longitudinal NMPC,
2. lateral-directional NMPC.

This approach is used before attempting a fully integrated NMPC.

The full 6-DOF model will be used as the nonlinear simulation plant, while reduced-order models will initially be used as prediction models inside the NMPC controllers.

---

## 11. Longitudinal NMPC Model

The longitudinal NMPC state vector is defined as:

```text
x_lon = [
    V,
    alpha,
    q,
    theta,
    h,
    T
]^T
```

where:

| Symbol  | Meaning                    |
| ------- | -------------------------- |
| `V`     | airspeed                   |
| `alpha` | angle of attack            |
| `q`     | pitch rate                 |
| `theta` | pitch angle                |
| `h`     | altitude                   |
| `T`     | total or equivalent thrust |

The longitudinal input vector is:

```text
u_lon = [
    delta_e_cmd,
    tau_cmd
]^T
```

where:

* `delta_e_cmd` is the commanded elevator deflection,
* `tau_cmd` is the commanded equivalent throttle input.

This model will be used for modes such as:

* altitude hold,
* speed hold,
* vertical speed mode,
* flight level change,
* simplified VNAV tracking,
* glideslope tracking.

---

## 12. Lateral-Directional NMPC Model

The lateral-directional NMPC state vector is defined as:

```text
x_lat = [
    beta,
    p,
    r,
    phi,
    psi,
    e_y
]^T
```

where:

| Symbol | Meaning                     |
| ------ | --------------------------- |
| `beta` | sideslip angle              |
| `p`    | roll rate                   |
| `r`    | yaw rate                    |
| `phi`  | roll angle                  |
| `psi`  | heading angle               |
| `e_y`  | lateral path tracking error |

The lateral-directional input vector is:

```text
u_lat = [
    delta_a_cmd,
    delta_r_cmd
]^T
```

where:

* `delta_a_cmd` is the commanded effective aileron deflection,
* `delta_r_cmd` is the commanded effective rudder deflection.

This model will be used for modes such as:

* roll hold,
* heading select,
* simplified LNAV tracking,
* localizer capture,
* cross-track error minimization.

---

## 13. Simulation Plant and Prediction Model

The project distinguishes between:

1. the nonlinear simulation plant,
2. the NMPC prediction model.

The nonlinear simulation plant should be as complete as practical within the scope of the project. It contains:

* full 6-DOF rigid-body dynamics,
* aerodynamic forces and moments,
* engine forces and moments,
* gravity,
* actuator dynamics,
* engine dynamics,
* atmospheric model.

The NMPC prediction model may be simpler. This is acceptable because practical MPC implementations often use reduced-order models to reduce computational complexity.

However, the prediction model must remain dynamically consistent with the plant in the operating region of interest.

---

## 14. Trim and Validation Assumptions

The model will be validated through trim and dynamic response tests.

Trim conditions will initially include:

* steady level cruise,
* steady climb,
* steady descent,
* approach condition.

The following quantities should be close to zero in a properly trimmed steady flight condition:

```text
u_dot, v_dot, w_dot, p_dot, q_dot, r_dot
```

For level flight, the flight path angle should be close to zero and altitude should remain approximately constant.

Validation will include qualitative checks of:

* phugoid mode,
* short-period mode,
* Dutch roll mode,
* roll mode,
* spiral mode.

The validation goal is not to exactly reproduce a certified Boeing 777 simulator, but to obtain physically reasonable wide-body aircraft behaviour.

---

## 15. Important Modelling Rule

The conventions in this document must remain consistent with:

* MATLAB helper files,
* Simulink 6-DOF blocks,
* aerodynamic force and moment equations,
* actuator models,
* engine models,
* trim scripts,
* NMPC prediction models,
* validation plots,
* thesis text.

If a convention is changed later, all dependent files must be reviewed.

In particular, sign conventions for elevator, pitching moment, angle of attack and body-axis `z_b` direction must be checked carefully, because inconsistencies in these definitions can make the aircraft model unstable or physically incorrect.
