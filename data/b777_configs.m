function cfg = b777_configs()
%B777_CONFIGS Aircraft configurations: clean, approach, landing.

cfg = struct([]);

cfg(1).name = "clean";
cfg(1).flap_deg = 0;
cfg(1).gear_down = false;

cfg(2).name = "approach";
cfg(2).flap_deg = NaN;
cfg(2).gear_down = false;

cfg(3).name = "landing";
cfg(3).flap_deg = NaN;
cfg(3).gear_down = true;

end
