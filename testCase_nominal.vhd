library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library osvvm;
--use osvvm.AlertLogPkg.all; -- used for logging and assertions
context osvvm.OsvvmContext;

entity testCase_nominal is
end entity;

architecture sim of testCase_nominal is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    constant G_CLK_HZ       : integer := 50_000_000;
    constant G_BITWIDTH     : integer := 32;
    constant G_OUTPUT_HZ    : integer := 400;
    constant G_STOP_US      : integer := 1500;

    constant CLK_PERIOD     : time  := 20 ns;
    constant TOLERANCE      : time  := 2 * CLK_PERIOD;
    constant C_TESTNAME     : string  := "testCase_nominal";

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal tb_clk       : std_logic := '0';
    signal tb_rst_n     : std_logic := '1';
    signal tb_stop_sig  : std_logic := '0';
    signal tb_pulse_us  : std_logic_vector(G_BITWIDTH-1 downto 0) := (others => '0');
    signal tb_pwm_sig   : std_logic;

    --------------------------------------------------------------------
    -- Procedures
    --------------------------------------------------------------------
    procedure set_pulse_us (
        signal tb_pulse_us : out std_logic_vector;
        constant us_int : in integer
    ) is
    begin
        tb_pulse_us <= std_logic_vector(to_unsigned(us_int, G_BITWIDTH));
    end procedure;

begin

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    dut : entity work.pwm_gen
        generic map (
            G_CLK_HZ    => G_CLK_HZ,
            G_BITWIDTH  => G_BITWIDTH,
            G_OUTPUT_HZ => G_OUTPUT_HZ,
            G_STOP_US   => G_STOP_US
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

        Log(C_TESTNAME & ": Starting tb_pwm_gen", INFO);

        ----------------------------------------------------------------
        -- Initial state
        ----------------------------------------------------------------
        tb_rst_n <= '1';
        set_pulse_us(tb_pulse_us, 0);

        wait for 1 ms;

        ----------------------------------------------------------------
        -- Test 0: Disabled
        ----------------------------------------------------------------
        Log( C_TESTNAME & ": Test 0 - Disabled output low", INFO);
        t_us := 100;
        set_pulse_us(tb_pulse_us, t_us);

        -- make sure output signal stays low when disabled and pulse us != 0
        wait until tb_pwm_sig = '1' for 1 ms;
        wait for 0 ns;
        if tb_pwm_sig = '0' then
            AffirmIf(TRUE,  C_TESTNAME & ":    TEST 0 PASSED, Signal stayed low during disable period");
        else
            AffirmIf(FALSE, C_TESTNAME & ":    TEST 0 FAILED, Signal went high during disable period");
        end if;

        ----------------------------------------------------------------
        -- Test 1: Pulse Width 0
        ----------------------------------------------------------------
        Log( C_TESTNAME & ": Test 1: Pulse width set to 0", INFO);
        t_us := 0;
        set_pulse_us(tb_pulse_us, t_us);

        -- make sure output signal stays low when pulse width = 0
        wait until tb_pwm_sig = '1' for 1 ms;
        wait for 0 ns;
        if tb_pwm_sig = '0' then
            AffirmIf(TRUE,  C_TESTNAME & ":    TEST 1 PASSED, Signal stayed low when pulse_us = 0");
        else
            AffirmIf(FALSE, C_TESTNAME & ":    TEST 1 FAILED, Signal went high when pulse_us = 0");
        end if;

        ----------------------------------------------------------------
        -- Test 2: Pulse Width 1000
        ----------------------------------------------------------------
        t_us := 1000;
        for i in 2 to 6 loop
            Log( C_TESTNAME & ": TEST " & integer'image(i) & ": Pulse width set to " & integer'image(t_us), INFO);
            t_us := t_us + 100;
            set_pulse_us(tb_pulse_us, t_us);

            -- make sure output signal goes high at some point after fully enabled
            wait until tb_pwm_sig = '1' for t_us * 1 us + TOLERANCE;
            t_start := now;
            wait until tb_pwm_sig = '0' for t_us * 1 us + TOLERANCE;
            t_end := now;
            if t_end - t_start >= t_us * 1 us - TOLERANCE and t_end - t_start <= t_us * 1 us + TOLERANCE then
                AffirmIf(TRUE,  C_TESTNAME & ":    TEST " & integer'image(i) & " PASSED, Signal stayed high for correct duration when pulse_us = " & integer'image(t_us));
            else
                AffirmIf(FALSE, C_TESTNAME & ":    TEST " & integer'image(i) & " FAILED, Signal stayed high for incorrect duration when pulse_us = " & integer'image(t_us));
            end if;

            wait for t_gap;
        end loop;

        wait for 1 ms;


        ----------------------------------------------------------------
        -- Done
        ----------------------------------------------------------------
        Log( C_TESTNAME & ": All tests completed", INFO);

        EndOfTestReports;
        stop;
        wait;
    end process;

end architecture;