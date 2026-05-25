library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library osvvm;
--use osvvm.AlertLogPkg.all; -- used for logging and assertions
context osvvm.OsvvmContext;

entity testCase_random is
end entity;

architecture sim of testCase_random is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    -- DUT constants
    constant C_CLK_HZ       : integer := 50_000_000;
    constant C_BITWIDTH     : integer := 32;
    constant C_GAP_US       : integer := 1000;
    constant C_STOP_US      : integer := 1500;

    -- Testbench constants
    constant C_NUM_TESTS    : integer := 50; -- number of tests
    constant C_CLK_PRD      : time    := 20 ns;
    constant C_TLRNCE       : time    := 2 * C_CLK_PRD;

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal tb_clk       : std_logic := '0';
    signal tb_rst_n     : std_logic := '1';
    signal tb_stop      : std_logic := '0';
    signal tb_pulse_us  : std_logic_vector(C_BITWIDTH-1 downto 0) := (others => '0');
    signal tb_pwm_sig   : std_logic;

    -- Response done signal
    signal resp_done : boolean := false;

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
            C_CLK_HZ        => C_CLK_HZ,
            C_BITWIDTH      => C_BITWIDTH,
            C_GAP_US        => C_GAP_US,
            C_STOP_US       => C_STOP_US
        )
        port map (
            pl_clk      => tb_clk,
            rst_n       => tb_rst_n,
            stop_sig    => tb_stop,
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
            wait for C_CLK_PRD / 2;
            tb_clk <= '1';
            wait for C_CLK_PRD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim_proc : process
        variable RV         : RandomPType;
        variable t_us       : integer   := 0;
        variable t_start    : time      := 0 ns;
        variable t_end      : time      := 0 ns;
    begin
        SetLogEnable(INFO, TRUE);
        SetLogEnable(PASSED, TRUE);
        SetLogEnable(DEBUG, TRUE);

        Log("Starting tb_pwm_gen", INFO);

        ----------------------------------------------------------------
        -- Initial state
        ----------------------------------------------------------------
        tb_rst_n <= '1';
        set_pulse_us(tb_pulse_us, 0);
        RV.InitSeed (RV'instance_name);

        ----------------------------------------------------------------
        -- RANDOM Test
        ----------------------------------------------------------------
        for i in 0 to C_NUM_TESTS - 1 loop

            t_us := RV.RandInt(1100, 1900); -- randomize pulse width
            Log("RANDOM: Pulse " & integer'image(i) & " - Width set to " & integer'image(t_us) & " us", INFO); -- log pulses
            set_pulse_us(tb_pulse_us, t_us); -- send pulse
            
            wait for RV.RandInt(t_us/2, t_us * 2) * 1 us; -- wait random amount

        end loop;
        wait for 1 ms;

        ----------------------------------------------------------------
        -- Done
        ----------------------------------------------------------------
        Log( "stim_proc done", INFO);

        wait until resp_done = true;
        EndOfTestReports;
        stop;
        wait;
    end process;
    
    --------------------------------------------------------------------
    -- Response
    --------------------------------------------------------------------
    resp_proc : process
        variable t_us       : time := 0 ns; -- pulse us
        variable t_init     : time := 0 ns; -- initial loop time stamp
        variable t_start    : time := 0 ns; -- start of pulse time stamp
        variable t_end      : time := 0 ns; -- end of pulse time stamp
        variable t_width    : time := 0 ns; -- width of pulse

        variable pass       : integer := 0; -- number of passes (correct duration)
        variable short      : integer := 0; -- high too short
        variable long       : integer := 0; -- high too long
        variable fail       : integer := 0; -- number of fails (incorrect duration or false neg)
        variable false_neg  : integer := 0; -- should be high while low
    begin
        ----------------------------------------------------------------
        -- Test for Pulse Duration
        ----------------------------------------------------------------
        for i in 0 to C_NUM_TESTS - 1 loop
            t_init := now;

            -- wait for signal to go high
            wait until tb_pwm_sig = '1' for C_GAP_US * 1 us + C_TLRNCE;
            t_us := to_integer(unsigned(tb_pulse_us)) * 1 us; -- capture pulse us at moment of signal going high
            t_start := now;

            -- detect false negative
            if t_start - t_init > C_GAP_US * 1 us + C_TLRNCE then
                AffirmIf(FALSE,  "RANDOM: FAIL - Signal stayed low when it should have gone high at " & time'image(now));
                false_neg   := false_neg + 1;
                fail        := fail + 1;
            end if;

            -- wait for pulse to go low
            wait until tb_pwm_sig = '0' for 1900 us + C_TLRNCE;
            t_end   := now;
            t_width := t_end - t_start;

            -- pass
            if t_width >= t_us - C_TLRNCE and t_width <= t_us + C_TLRNCE then
                AffirmIf(TRUE,
                    "RANDOM: PASS - Signal stayed high for " &
                    integer'image(t_width / 1 us) &
                    " when pulse_us = " &
                    integer'image(t_us / 1 us)
                );
                pass := pass + 1;

            -- short
            elsif t_width < t_us - C_TLRNCE then
                AffirmIf(FALSE, "RANDOM: FAIL - Short, Signal stayed high for incorrect duration " 
                    & integer'image((t_end - t_start) / 1 us) & 
                    " us when pulse_us = " & integer'image(t_us / 1 us) & 
                    " us, gap = " & 
                    integer'image((t_us - t_width) / 1 us)
                );
                short   := short + 1;
                fail    := fail + 1;

            -- long
            elsif t_width > t_us + C_TLRNCE then
                AffirmIf(FALSE, "RANDOM: FAIL - Long, Signal stayed high for incorrect duration " & 
                    integer'image((t_end - t_start) / 1 us) & 
                    " when pulse_us = " & 
                    integer'image(t_us / 1 us) & 
                    ", gap = " & 
                    integer'image((t_us - t_width) / 1 us)
                );
                long := long + 1;
                fail := fail + 1;
            end if;
            wait for 0 ns;

        end loop;

        wait for 1 ms;
        Log("RESULTS: pass: " & integer'image(pass) &
        ", fail: " & integer'image(fail) &
        ", short: " & integer'image(short) &
        ", long: " & integer'image(long) &
        ", false neg: " & integer'image(false_neg));

        resp_done <= true;
        wait;
    end process;

end architecture;