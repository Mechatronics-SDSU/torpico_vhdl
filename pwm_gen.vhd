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
-- microseconds from G_STOP_US.
--
-- Dependencies: N/A
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- Make absolutely sure to set the G_CLK_HZ generic to the receiving clock frequency. 
-- This module may have negative slack above 100 MHz, recommended frequncy is 50MHz.
-- pulse_us should be > 2
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_gen is
    generic (
        G_CLK_HZ    : integer                   := 50_000_000;    -- input clk hz (used for divider)
        G_BITWIDTH  : integer                   := 32;            -- input vector bitwidth
        G_OUTPUT_HZ : integer range 1 to 400    := 400;           -- output frequency in Hz
        G_STOP_US   : integer                   := 1500           -- after receiving a reset signal, send this pulse width until reset
    );
    port (
        pl_clk      : in std_logic;                                 -- clock signal
        rst_n       : in std_logic;                                 -- reset (active low)
        stop_sig    : in std_logic;                                 -- kill signal, if high, immediately stops output and ignores input until reset
        pulse_us    : in std_logic_vector(G_BITWIDTH-1 downto 0);   -- pulse width in microseconds
        pwm_sig     : out std_logic                                 -- output signal
    );
end entity;

architecture rtl of pwm_gen is
    -- constants
    constant C_CLKS_PER_US  : integer range 0 to integer'high := G_CLK_HZ / 10**6;          -- pulse width adjustment to cycles
    constant C_PRD_CLKS     : integer range 0 to integer'high := G_CLK_HZ / G_OUTPUT_HZ;    -- output period in clks

    -- states
    type state_type is (
        S_PASSIVE,  -- passive state which outputs signal continuous 1 or 0 if pulse_us = 1 or 0, transitions to low if real pulse given
        S_HIGH,     -- signal high for limited duration
        S_LOW       -- signal low for correct amount to ensure square wave matches output Hz generic
        );
    signal state        : state_type := S_PASSIVE; -- state tracking signal, initialized to passive for binary operation
    signal next_state   : state_type := S_PASSIVE; -- next state used for transitions

    -- signals
    signal clk_cnt          : integer range 0 to C_PRD_CLKS := 0;   -- clock counter
    signal pulse_clk_cnt    : integer range 0 to C_PRD_CLKS := 1;   -- max clock count during pulse
    signal max_clk_cnt      : integer range 0 to C_PRD_CLKS := 1;   -- max clock count for period
    signal pwm_sig_buf      : std_logic := '0'; -- output buffer
    --signal stop_flag        : std_logic := '0'; -- stop flag

begin
    process(pl_clk, rst_n)
    begin
        ----------------------------------------------------------------------------------
        -- RESET LOGIC
        ----------------------------------------------------------------------------------
        if rst_n = '0' then
            state           <= S_PASSIVE;   -- reset state
            next_state      <= S_PASSIVE;   -- reset next state
            clk_cnt         <= 0;           -- keep clk at 0
            pulse_clk_cnt   <= 1;           -- reset pulse clk cnt
            max_clk_cnt     <= 1;           -- reset max clk cnt
            pwm_sig_buf     <= '0';         -- reset output buffer
            --signal stop_flag        : std_logic := '0'; -- stop flag

        ----------------------------------------------------------------------------------
        -- CLOCK LOOP
        ----------------------------------------------------------------------------------
        elsif rising_edge(pl_clk) then
            -- set stop flag high after stop signal high
            -- if stop_sig = '1' then
            --     stop_flag <= '1';
            -- end if;
            
            -- clock counter logic
            if clk_cnt < max_clk_cnt then
                clk_cnt <= clk_cnt + 1;
            else
                -- setup next state
                state   <= next_state;
                clk_cnt <= 0;

                -- assign pulse clock count to either stop us or pulse us
                if state = S_LOW then
                    if stop_sig = '1' then
                        pulse_clk_cnt <= G_STOP_US * C_CLKS_PER_US; -- set pulse clk cnt to stop us
                    else
                        pulse_clk_cnt <= to_integer(unsigned(pulse_us)) * C_CLKS_PER_US; -- set pulse clk cnt from pulse_us
                    end if;
                end if;
            end if;

            -- state machine logic
            case state is
                -- only pass 1/0 if input is 1/0, else transition to low
                when S_PASSIVE =>
                    if to_integer(unsigned(pulse_us)) < 2 and stop_sig = '0' then
                        pwm_sig_buf <= pulse_us(0); -- output 1 or 0 if input is 1 or 0
                    else
                        state <= S_LOW; -- otherwise transition to low state
                    end if;

                -- signal high state
                when S_HIGH =>
                    pwm_sig_buf <= '1';                 -- set output signal high
                    max_clk_cnt <= pulse_clk_cnt - 1;   -- set max count
                    next_state <= S_LOW;                -- transition to low

                -- signal low state
                when S_LOW =>
                    pwm_sig_buf <= '0';                             -- set output signal low
                    max_clk_cnt <= C_PRD_CLKS - pulse_clk_cnt - 1;  -- set max count
                    next_state <= S_HIGH;                           -- transition to high

                -- other state
                when others =>
                    state <= S_PASSIVE; -- transition to passive
            end case;
        end if;
    end process;

    -- assign output to buffer
    pwm_sig <= pwm_sig_buf;
end architecture;