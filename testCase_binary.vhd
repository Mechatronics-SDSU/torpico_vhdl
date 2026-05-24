library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library osvvm;
--use osvvm.AlertLogPkg.all; -- used for logging and assertions
context osvvm.OsvvmContext;

entity testCase_binary is
end entity;

architecture sim of testCase_binary is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    constant C_CLK_HZ   : integer := 50_000_000;
    constant C_BITWIDTH : integer := 32;
    constant C_GAP_US   : integer := 1000;

    constant C_STOP_US  : integer := 1500;
    constant CLK_PERIOD : time  := 20 ns;
    constant TOLERANCE  : time  := 2 * CLK_PERIOD;

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal tb_clk       : std_logic := '0';
    signal tb_rst_n     : std_logic := '1';
    signal tb_stop_sig  : std_logic := '0';
    signal tb_pulse_us  : std_logic_vector(C_BITWIDTH-1 downto 0) := (others => '0');
    signal tb_pwm_sig   : std_logic;

    --------------------------------------------------------------------
    -- Testbench signals
    --------------------------------------------------------------------
    signal false_pos    : integer := 0;
    signal false_neg    : integer := 0;
    signal true_pos     : integer := 0;
    signal true_neg     : integer := 0;

    --------------------------------------------------------------------
    -- Procedures
    --------------------------------------------------------------------
    procedure set_pulse_us (
        signal tb_pulse_us : out std_logic_vector;
        constant us_int : in integer
    ) is
    begin
        tb_pulse_us <= std_logic_vector(to_unsigned(us_int, C_BITWIDTH));
    end procedure;

begin

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    dut : entity work.pwm_gen
        generic map (
            C_CLK_HZ    => C_CLK_HZ,
            C_BITWIDTH  => C_BITWIDTH,
            C_GAP_US    => C_GAP_US,
            C_STOP_US   => C_STOP_US
        )
        port map (
            pl_clk      => tb_clk,
            rst_n       => tb_rst_n,
            stop_sig    => tb_stop_sig,
            pulse_us    => tb_pulse_us,
            pwm_sig     => tb_pwm_sig
        );

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    clk_gen : process
    begin
        while true loop
            tb_clk <= '0';
            wait for CLK_PERIOD / 2;
            tb_clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim_proc : process
        variable t_us       : integer   := 0;
        variable t_start    : time      := 0 ns;
        variable t_end      : time      := 0 ns;
        variable t_gap      : time      := 2 ms;
    begin
        SetLogEnable(INFO, TRUE);
        SetLogEnable(PASSED, TRUE);
        SetLogEnable(DEBUG, TRUE);

        Log("Starting tb_pwm_gen", INFO);

        for i in 0 to 4 loop
            tb_pulse_us(0) <= '0';
            wait for 1 ms;
            tb_pulse_us(0) <= '1';
            wait for 1 ms;
        end loop;
        ----------------------------------------------------------------
        -- Done
        ----------------------------------------------------------------
        Log( "All tests completed", INFO);
        Log("RESULTS: False pos: " & integer'image(false_pos) & " False neg: " & integer'image(false_neg) & " True pos: " & integer'image(true_pos) & " True neg: " & integer'image(true_neg));

        EndOfTestReports;
        stop;
        wait;
    end process;

    --------------------------------------------------------------------
    -- Response
    --------------------------------------------------------------------
    resp_proc : process
    begin
        for i in 0 to 4 loop
            wait until tb_pwm_sig = '0' for TOLERANCE;
            if tb_pwm_sig = '0' then
                AffirmIf(true, "True negative");
                true_neg <= true_neg + 1;
            else
                AffirmIf(false, "False positive");
                false_pos <= false_pos + 1;
            end if;
            wait for 1 ms;
            wait until tb_pwm_sig = '1' for TOLERANCE;
            if tb_pwm_sig = '1' then
                AffirmIf(true, "True positive");
                true_pos <= true_pos + 1;
            else
                AffirmIf(false, "False negative");
                false_neg <= false_neg + 1;
            end if;
            wait for 1 ms;
        end loop;

    end process;

end architecture;