function engine = b777_engine_model()
%B777_ENGINE_MODEL Initial engine model parameters.
%
% First model:
%   T = throttle * T_max(h, Mach)
% with first-order spool dynamics.

engine = struct();
engine.n_engines = 2;
engine.Tmax_sl_per_engine_N = NaN;
engine.spool_tau_s = NaN;

end
