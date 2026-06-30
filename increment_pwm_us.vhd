----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/15/2026 03:48:22 PM
-- Design Name: 
-- Module Name: increment_pwm_us - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity increment_pwm_us is
    port (
        clk    : in  std_logic;
        rst_n  : in  std_logic;
        add    : in  std_logic;
        sub    : in  std_logic;
        pwm_us : out std_logic_vector(31 downto 0)
    );
end increment_pwm_us;

architecture rtl of increment_pwm_us is
    signal pwm_us_i : unsigned(31 downto 0) := to_unsigned(1500, 32);

    signal add_sync_0, add_sync_1, add_prev : std_logic := '0';
    signal sub_sync_0, sub_sync_1, sub_prev : std_logic := '0';
begin

    process(clk)
    begin
        if rst_n = '0' then
            pwm_us_i <= to_unsigned(1500, 32);
            
        elsif rising_edge(clk) then
            add_sync_0 <= add;
            add_sync_1 <= add_sync_0;
            add_prev   <= add_sync_1;

            sub_sync_0 <= sub;
            sub_sync_1 <= sub_sync_0;
            sub_prev   <= sub_sync_1;

            if add_sync_1 = '1' and add_prev = '0' then
                pwm_us_i <= pwm_us_i + 1;
            elsif sub_sync_1 = '1' and sub_prev = '0' then
                if pwm_us_i > 0 then
                    pwm_us_i <= pwm_us_i - 1;
                end if;
            end if;
        end if;
    end process;

    pwm_us <= std_logic_vector(pwm_us_i);

end architecture;

