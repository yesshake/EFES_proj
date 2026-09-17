# 50 MHz oscillator connected to sys_top.clk_50m.
create_clock -name clk_50m -period 20.000 [get_ports {clk_50m}]
create_clock -name aud_bclk -period 325.52 [get_ports {aud_bclk}]

set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m}] \
    -group [get_clocks {aud_bclk}]
# Derive the generated audio PLL clock and apply the device-specific
# clock uncertainty calculated by TimeQuest.
derive_pll_clocks
derive_clock_uncertainty
