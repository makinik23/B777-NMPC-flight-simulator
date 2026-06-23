function cfg = b777_configs()
%B777_CONFIGS Aircraft configurations: clean, approach, landing.

cfg = struct([]);

cfg(1).name = "clean";
cfg(1).flap_deg = 0;
cfg(1).slat_deployed = false;
cfg(1).gear_down = false;
cfg(1).notes = "Clean cruise configuration.";

cfg(2).name = "approach";
cfg(2).flap_deg = 20;
cfg(2).slat_deployed = true;
cfg(2).gear_down = false;
cfg(2).notes = "Nominal CRM-HL/DATCOM-ready approach seed configuration.";

cfg(3).name = "landing";
cfg(3).flap_deg = 30;
cfg(3).slat_deployed = true;
cfg(3).gear_down = true;
cfg(3).notes = "Nominal CRM-HL/DATCOM-ready landing seed configuration.";

end
