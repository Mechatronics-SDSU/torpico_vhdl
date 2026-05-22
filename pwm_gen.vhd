----------------------------------------------------------------------------------
-- Company: SDSU Mechatronics Club
-- Engineer: Ryan Sundermeyer
-- 
-- Create Date: 03/13/2026 11:00:26 AM
-- Design Name: PWM Generator
-- Module Name: pwm_gen - rtl
-- Project Name: Torpico Electrical System
-- Target Devices: Zybo Z7 s20
-- Tool Versions: Vivado 2024.2
-- Description: 
-- Generates a PWM signal of a pulse width in microseconds from pulse_us input vector.
-- Can either run in pulse mode, where it only sends one pulse at a time whenever the input pulse_us changes (like
-- for Blue Robotics T200 Motors with their basic ESCs), or send a continuous square wave (like for most servos).
-- Because motors like the T200s actually stop at 1500us not 0, the reset behavior can be set to send a specific pulse width in 
-- microseconds from C_RST_PW_US. In pulse mode, this just sends a single pulse and waits, and in square wave mode this sends a
-- continuous square wave of that pulse width as long as the reset signal is active.
--
-- Dependencies: N/A
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- Make absolutely sure to set the C_CLK_HZ generic to the receiving clock frequency. 
-- This module may have negative slack above 100 MHz, recommended frequncy is 50MHz.
-- pulse_us should be > 2
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_gen is
    generic (
        C_CLK_HZ        : integer := 50_000_000;    -- input clk hz for divider
        C_BITWIDTH      : integer := 32;            -- bitwidth
        C_PULSE_MODE    : boolean := false;         -- mode of pwm signal (T for pulse, F for continuous square wave)
        C_GAP_US        : integer := 100;           -- minimum gap between pulses in microseconds, only used in pulse mode
        C_STOP_PW_US    : integer := 0              -- after receiving a reset signal, send this pulse width (or 0 for none)
    );
    port (
        pl_clk      : in std_logic;                                 -- clock signal
        rst_n       : in std_logic;                                 -- reset (active low)
        stop_sig    : in std_logic;                                 -- kill signal, if high, immediately stops output and ignores input until reset
        pulse_us    : in std_logic_vector(C_BITWIDTH-1 downto 0);   -- pulse width in microseconds
        pwm_sig     : out std_logic                                 -- output signal
    );
        
end entity;

architecture rtl of pwm_gen is
    ----------------------------------------------------------------------------------
    -- SIGNALS
    ----------------------------------------------------------------------------------

    constant C_CLKS_PER_US  : integer   := C_CLK_HZ / 1_000_000;    -- pulse width adjustment to cycles
    signal clk_cnt          : integer   := 0;                       -- clock counter
    signal clk_cnt_max      : integer   := 0;                       -- clock counter max
    signal stop_mode        : boolean   := false;                   -- flag true while sending reset pulse/continuous pwm after reset received
    signal pwm_sig_buf      : std_logic := '0';                     -- output buffer for stability
    signal pulse_us_buf0    : std_logic_vector(C_BITWIDTH-1 downto 0) := (others => '0'); -- input buffer 0 for stability and previous us
    signal pulse_us_buf1    : std_logic_vector(C_BITWIDTH-1 downto 0) := (others => '0'); -- input buffer 1 for stability and previous us
begin
    process(pl_clk, rst_n) 
    begin
        ----------------------------------------------------------------------------------
        -- RESET LOGIC
        ----------------------------------------------------------------------------------
        if rst_n = '0' then -- reset once
            clk_cnt         <= 0;               -- keep clk at 0
            clk_cnt_max     <= 0;               -- keep clk max at 0
            pulse_us_buf0   <= (others => '0'); -- set input buffers to 0
            pulse_us_buf1   <= (others => '0');
            pwm_sig_buf     <= '0';             -- reset output buffer
            stop_mode       <= false;           -- clear reset mode

        ----------------------------------------------------------------------------------
        -- CLOCK LOOP
        ----------------------------------------------------------------------------------
        elsif rising_edge(pl_clk) then
                -- assign buffers
                pulse_us_buf0   <= pulse_us; -- double buffered input
                pulse_us_buf1   <= pulse_us_buf0;

                if not stop_mode then -- if not in stop mode, calculate clk max from input pulse width
                    clk_cnt_max <= to_integer(unsigned(pulse_us_buf0)) * C_CLKS_PER_US; -- recalculate clk max from input
                else -- if in reset mode, calculate clk max from reset pulse width
                    clk_cnt_max <= C_RST_PW_US * C_CLKS_PER_US;
                end if;

                if stop_sig = '1' then -- if stop signal is high, immediately stop output and ignore input until reset
                    stop_mode <= true; -- set reset mode to ignore input and send reset pulse
                end if;

                ----------------------------------------------------------------------------------
                -- PULSE MODE
                ----------------------------------------------------------------------------------
                if C_PULSE_MODE and clk_cnt_max /= 0 then 
                    -- create pulse
                    if clk_cnt < clk_cnt_max - 1 then   -- count up to pulse width
                        pwm_sig_buf <= '1';             -- output signal high during pulse
                        clk_cnt     <= clk_cnt + 1;     -- increment counter
                    -- wait after pulse
                    elsif clk_cnt < clk_cnt_max + C_GAP_US * C_CLKS_PER_US - 1 then -- wait for 1 us after pulse
                        pwm_sig_buf <= '0';                                         -- output signal low after pulse is done
                        clk_cnt     <= clk_cnt + 1;                                 -- increment counter
                    -- conditional restart after pules and wait done
                    else
                        -- clk counter reset logic
                        if pulse_us /= pulse_us_buf1 or stop_mode then  -- restart if input pulse us changes or reset active
                            clk_cnt <= 0;                               -- zero counter to start new pulse
                            stop_mode <= false when stop_mode;          -- clear reset mode after starting pulse
                        end if;
                    end if;
                
                ----------------------------------------------------------------------------------
                -- SQUARE WAVE MODE
                ----------------------------------------------------------------------------------
                elsif not C_PULSE_MODE and clk_cnt_max /= 0 then -- if not in pulse mode
                    -- create square wave
                    if clk_cnt < 2 * clk_cnt_max - 1 then 
                    
                        -- output signal low for second half of period or reset active
                        if clk_cnt >= clk_cnt_max - 1 then --or stop_mode then 
                            pwm_sig_buf <= '0';
                        else
                            pwm_sig_buf <= '1'; -- output signal high for first half of period
                        end if;
                        
                        clk_cnt <= clk_cnt + 1; -- increment clock counter
                    else -- reset after counter reaches period
                        clk_cnt <= 0; -- reset clock counter
                    end if;
                
                ----------------------------------------------------------------------------------
                -- clk_cnt_max = 0 CASE
                ----------------------------------------------------------------------------------
                else
                    pwm_sig_buf <= '0'; -- keep output low if pulse width is 0
                    clk_cnt     <= 0;   -- keep clk at 0
                end if;
        end if;
    end process;
    
    -- concurrently assign output to buffer value
    pwm_sig <= pwm_sig_buf; 
    
end architecture;