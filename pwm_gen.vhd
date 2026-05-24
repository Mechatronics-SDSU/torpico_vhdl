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
-- This module sends a continuous square wave.
-- Because motors like the T200s actually stop at 1500us not 0, the reset behavior can be set to send a specific pulse width in 
-- microseconds from C_STOP_US.
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
        C_CLK_HZ    : integer := 50_000_000;    -- input clk hz for divider
        C_BITWIDTH  : integer := 32;            -- bitwidth
        C_GAP_US    : integer := 1000;          -- minimum gap between pulses in microseconds
        C_STOP_US   : integer := 1500           -- after receiving a reset signal, send this pulse width (or 0 for none)
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
    -- constants
    constant C_CLKS_PER_US : integer := C_CLK_HZ / 1_000_000;    -- pulse width adjustment to cycles

    -- states
    type state_type is (S_HIGH, S_LOW);
    signal state : state_type := S_LOW; -- state tracking signal

    -- signals
    signal clk_cnt          : integer   := 0;   -- clock counter
    signal clk_cnt_max      : integer   := 0;   -- max clock count
    signal pwm_sig_buf      : std_logic := '0'; -- output buffer
    signal stop_flag        : std_logic := '0'; -- stop flag

begin
    process(pl_clk, rst_n)
    begin
        ----------------------------------------------------------------------------------
        -- RESET LOGIC
        ----------------------------------------------------------------------------------
        if rst_n = '0' then
            clk_cnt         <= 0;       -- keep clk at 0
            clk_cnt_max     <= 0;       -- reset clk cnt max
            pwm_sig_buf     <= '0';     -- reset output buffer
            stop_flag       <= '0';     -- reset stop flag
            state           <= S_LOW;   -- reset state

        ----------------------------------------------------------------------------------
        -- CLOCK LOOP
        ----------------------------------------------------------------------------------
        elsif rising_edge(pl_clk) then
            -- set stop flag high after stop signal high
            if stop_sig = '1' then
                stop_flag <= '1';
            end if;
                
            -- binary behavior if sent a 1 or 0
            if unsigned(pulse_us) <= 1 and stop_flag = '0' then -- branch if stop sent for safety reasons
                pwm_sig_buf <= pulse_us(0);

            -- normal PWM behavior
            else
                -- state machine logic
                case state is
                    -- signal high state
                    when S_HIGH =>
                        pwm_sig_buf <= '1'; -- set output signal high

                        if clk_cnt >= clk_cnt_max - 1 then -- count up to pulse width us
                            clk_cnt <= 0;       -- reset clock counter
                            state   <= S_LOW;   -- transition to low state
                        else
                            clk_cnt <= clk_cnt + 1; -- increment counter
                        end if;

                    -- signal low state
                    when S_LOW =>
                        pwm_sig_buf <= '0'; -- set output signal low

                        if clk_cnt >= C_GAP_US * C_CLKS_PER_US - 1 then 
                            clk_cnt <= 0;

                            -- assign max clock count
                            if stop_flag = '1' then
                                clk_cnt_max <= C_STOP_US * C_CLKS_PER_US;   -- set max clk cnt to stop us
                                stop_flag   <= stop_sig;                    -- reset stop to low if input is low
                            else
                                clk_cnt_max <= to_integer(unsigned(pulse_us)) * C_CLKS_PER_US; -- typical max count from pulse us
                            end if;

                            state <= S_HIGH; -- transition to high state
                        else
                            clk_cnt <= clk_cnt + 1; -- increment counter
                        end if;

                    -- other state
                    when others =>
                        state <= S_LOW;
                end case;
            end if;
        end if;
    end process;

    -- assign output to buffer
    pwm_sig <= pwm_sig_buf;

end architecture;