# 50 MHz oscillator connected to sys_top.clk_50m.
create_clock -name clk_50m -period 20.000 [get_ports {clk_50m}]

# Derive the generated audio PLL clock and apply the device-specific
# clock uncertainty calculated by TimeQuest.
derive_pll_clocks
derive_clock_uncertainty
