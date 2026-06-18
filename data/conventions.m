function conv = conventions()
% B777_CONVENTIONS
% Defines units, reference frames, sign conventions, state vectors and input
% vectors used in the B777-like nonlinear flight dynamics simulator.
%

    %% General modelling convention

    conv.project.aircraftClass = "Boeing 777-like wide-body transport aircraft";
    conv.project.modelType     = "educational nonlinear 6-DOF flight dynamics model";
    conv.project.environment   = "MATLAB/Simulink with Aerospace Toolbox/Blockset";

    %% Units

    conv.units.length       = "m";
    conv.units.time         = "s";
    conv.units.mass         = "kg";
    conv.units.force        = "N";
    conv.units.moment       = "N*m";
    conv.units.angle        = "rad";
    conv.units.angleOutput  = "deg";
    conv.units.velocity     = "m/s";
    conv.units.angularRate  = "rad/s";
    conv.units.density      = "kg/m^3";
    conv.units.pressure     = "Pa";
    conv.units.power        = "W";

    %% Reference frames

    % Navigation frame: local NED
    conv.frames.navigation.name = "NED";
    conv.frames.navigation.x    = "North";
    conv.frames.navigation.y    = "East";
    conv.frames.navigation.z    = "Down";
    conv.frames.navigation.note = ...
        "The navigation frame is a local North-East-Down frame. Altitude is h = -D.";

    % Body frame
    conv.frames.body.name = "Body";
    conv.frames.body.x    = "forward, through aircraft nose";
    conv.frames.body.y    = "right wing";
    conv.frames.body.z    = "down";
    conv.frames.body.note = ...
        "The body frame is right-handed: x_b forward, y_b right, z_b down.";

    % Wind frame
    conv.frames.wind.name = "Wind";
    conv.frames.wind.x    = "along air-relative velocity vector";
    conv.frames.wind.y    = "right side of aircraft";
    conv.frames.wind.z    = "downward component completing right-handed frame";
    conv.frames.wind.note = ...
        "Drag acts along -x_w, lift acts approximately along -z_w.";

    %% Kinematic quantities

    conv.kinematics.bodyVelocity.names = ["u", "v", "w"];
    conv.kinematics.bodyVelocity.units = ["m/s", "m/s", "m/s"];
    conv.kinematics.bodyVelocity.description = [
        "forward body-axis velocity component"
        "right body-axis velocity component"
        "down body-axis velocity component"
    ];

    conv.kinematics.bodyRates.names = ["p", "q", "r"];
    conv.kinematics.bodyRates.units = ["rad/s", "rad/s", "rad/s"];
    conv.kinematics.bodyRates.description = [
        "roll rate about +x_b"
        "pitch rate about +y_b"
        "yaw rate about +z_b"
    ];

    conv.kinematics.eulerAngles.names = ["phi", "theta", "psi"];
    conv.kinematics.eulerAngles.units = ["rad", "rad", "rad"];
    conv.kinematics.eulerAngles.description = [
        "roll angle"
        "pitch angle"
        "yaw/heading angle"
    ];

    conv.kinematics.alpha.definition = "alpha = atan2(w, u)";
    conv.kinematics.beta.definition  = "beta = asin(v / V)";
    conv.kinematics.airspeed.definition = "V = sqrt(u^2 + v^2 + w^2)";

    %% Sign conventions for moments

    conv.signs.moments.L = "+L produces positive roll rate p; right wing moves down";
    conv.signs.moments.M = "+M produces positive pitch rate q; aircraft nose moves up";
    conv.signs.moments.N = "+N produces positive yaw rate r; aircraft nose moves right";

    %% Control surface conventions

    % Elevator
    conv.controls.elevator.symbol = "delta_e";
    conv.controls.elevator.positive = "trailing edge down";
    conv.controls.elevator.expectedPitchingMoment = ...
        "For the selected physical convention, positive delta_e usually gives negative pitching moment; C_m_delta_e < 0.";

    % Effective aileron
    conv.controls.aileron.symbol = "delta_a";
    conv.controls.aileron.positive = ...
        "effective positive aileron: left aileron down, right aileron up";
    conv.controls.aileron.expectedRollingMoment = ...
        "Positive delta_a should produce positive rolling moment; C_l_delta_a > 0.";

    % Effective rudder
    conv.controls.rudder.symbol = "delta_r";
    conv.controls.rudder.positive = ...
        "effective positive rudder command produces positive yawing moment";
    conv.controls.rudder.expectedYawingMoment = ...
        "Positive delta_r should produce positive yawing moment; C_n_delta_r > 0.";

    % Throttle
    conv.controls.throttle.symbol = "tau";
    conv.controls.throttle.range  = "[0, 1]";
    conv.controls.throttle.note   = "tau = 0 means idle/minimum thrust, tau = 1 means maximum available thrust.";

    %% Full 6-DOF state vector

    conv.state.full6dof.names = [
        "N"
        "E"
        "D"
        "u"
        "v"
        "w"
        "phi"
        "theta"
        "psi"
        "p"
        "q"
        "r"
        "T1"
        "T2"
        "delta_e"
        "delta_a"
        "delta_r"
    ];

    conv.state.full6dof.units = [
        "m"
        "m"
        "m"
        "m/s"
        "m/s"
        "m/s"
        "rad"
        "rad"
        "rad"
        "rad/s"
        "rad/s"
        "rad/s"
        "N"
        "N"
        "rad"
        "rad"
        "rad"
    ];

    conv.state.full6dof.description = [
        "north position in NED frame"
        "east position in NED frame"
        "down position in NED frame"
        "body-axis forward velocity"
        "body-axis right velocity"
        "body-axis down velocity"
        "roll angle"
        "pitch angle"
        "yaw angle"
        "roll rate"
        "pitch rate"
        "yaw rate"
        "left engine thrust"
        "right engine thrust"
        "actual elevator deflection"
        "actual effective aileron deflection"
        "actual effective rudder deflection"
    ];

    %% Command input vector

    conv.input.command.names = [
        "delta_e_cmd"
        "delta_a_cmd"
        "delta_r_cmd"
        "tau_1_cmd"
        "tau_2_cmd"
    ];

    conv.input.command.units = [
        "rad"
        "rad"
        "rad"
        "-"
        "-"
    ];

    conv.input.command.description = [
        "commanded elevator deflection"
        "commanded effective aileron deflection"
        "commanded effective rudder deflection"
        "left engine throttle command"
        "right engine throttle command"
    ];

    %% Longitudinal NMPC reduced state

    conv.state.longitudinalNmpc.names = [
        "V"
        "alpha"
        "q"
        "theta"
        "h"
        "T"
    ];

    conv.state.longitudinalNmpc.units = [
        "m/s"
        "rad"
        "rad/s"
        "rad"
        "m"
        "N"
    ];

    conv.input.longitudinalNmpc.names = [
        "delta_e_cmd"
        "tau_cmd"
    ];

    conv.input.longitudinalNmpc.units = [
        "rad"
        "-"
    ];

    %% Lateral-directional NMPC reduced state

    conv.state.lateralNmpc.names = [
        "beta"
        "p"
        "r"
        "phi"
        "psi"
        "e_y"
    ];

    conv.state.lateralNmpc.units = [
        "rad"
        "rad/s"
        "rad/s"
        "rad"
        "rad"
        "m"
    ];

    conv.input.lateralNmpc.names = [
        "delta_a_cmd"
        "delta_r_cmd"
    ];

    conv.input.lateralNmpc.units = [
        "rad"
        "rad"
    ];

    %% Important modelling note

    conv.note = [
        "All conventions in this file must remain consistent with the Simulink 6-DOF block, "
        "aerodynamic force and moment model, trim scripts, and NMPC prediction models."
    ];

end