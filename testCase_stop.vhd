library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library osvvm;
--use osvvm.AlertLogPkg.all; -- used for logging and assertions
context osvvm.OsvvmContext;

entity testCase_stop is
end entity;

architecture sim of testCase_stop is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    -- DUT constants
    constant G_CLK_HZ       : integer := 50_000_000;
    constant G_BITWIDTH     : integer := 32;
    constant G_OUTPUT_HZ    : integer := 400;
    constant G_STOP_US      : integer := 1500;

    -- Testbench constants
    constant C_NUM_TESTS    : integer := 25; -- number of tests
    constant C_CLK_PRD      : time    := 20 ns;
    constant C_TLRNCE       : time    := 2 * C_CLK_PRD;
    constant C_MAX_US       : integer := 1900;
    constant C_MIN_US       : integer := 1100;
    constant C_TESTNAME     : string  := "testCase_stop";

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal tb_clk       : std_logic := '0';
    signal tb_rst_n     : std_logic := '0';
    signal tb_stop      : std_logic := '0';
    signal tb_pulse_us  : std_logic_vector(G_BITWIDTH-1 downto 0) := (others => '0');
    signal tb_pwm_sig   : std_logic;

    signal timeout      : time      := 3 ms;
    signal stim_done    : boolean   := false;
    signal resp_done    : boolean   := false;

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
            G_CLK_HZ        => G_CLK_HZ,
            G_BITWIDTH      => G_BITWIDTH,
            G_OUTPUT_HZ     => G_OUTPUT_HZ,
            G_STOP_US       => G_STOP_US
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
        RV.InitSeed (RV'instance_name);

        ----------------------------------------------------------------
        -- STOP Test
        ----------------------------------------------------------------
        for i in 0 to C_NUM_TESTS - 1 loop

            -- send stop signal occasionally
            if i mod 3 = 0 then
                tb_stop <= '1';
                Log(C_TESTNAME & ": Set stop_sig=1", INFO);
            end if;

            t_us := RV.RandInt(C_MIN_US, C_MAX_US); -- randomize pulse width
            Log(C_TESTNAME & ": Set pulse_us=" & integer'image(t_us) & " us", INFO); -- log pulses
            set_pulse_us(tb_pulse_us, t_us); -- send pulse

            -- reset after stop signal
            if tb_stop = '1' then
                wait until tb_pwm_sig = '0' for G_STOP_US * 1 us + C_TLRNCE; -- wait for signal to go low to not break with reset
                Log(C_TESTNAME & ": Set stop_sig=0, rst_n=0", INFO);
                tb_stop <= '0';
                tb_rst_n <= '0';
                wait for 2 * C_CLK_PRD;
                Log(C_TESTNAME & ": Set rst_n=1", INFO);
                tb_rst_n <= '1';
            else
                wait for RV.RandInt(t_us/2, t_us * 2) * 1 us; -- wait random amount
            end if;

        end loop;
        wait for 1 us / G_CLK_HZ;
        
        ----------------------------------------------------------------
        -- Done
        ----------------------------------------------------------------
        stim_done <= true;
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
        variable t_expected       : time := 0 ns; -- expected pulse width
        variable t_start    : time := 0 ns; -- start of pulse time stamp
        variable t_end      : time := 0 ns; -- end of pulse time stamp
        variable t_width    : time := 0 ns; -- width of pulse

        variable pass       : integer := 0; -- number of passes (correct duration)
        variable short      : integer := 0; -- high too short
        variable long       : integer := 0; -- high too long
        variable fail       : integer := 0; -- number of fails (incorrect duration or false neg)
        variable false_neg  : integer := 0; -- should be high while low

        variable pulse_us_was : integer     := 0; -- pulse_us at moment of signal going high
        variable stop_sig_was : std_logic   := '0'; -- stop_sig at moment of signal going high
    begin
        ----------------------------------------------------------------
        -- Response Loop
        ----------------------------------------------------------------
        resp_loop: while stim_done = false loop
            -- initialize loop
            t_end := now; -- reset end time
            wait until tb_pwm_sig = '1' or tb_rst_n = '0' for timeout; -- wait for output high
            
            ----------------------------------------------------------------
            -- Test Signals At Moment of Output Going High
            ----------------------------------------------------------------
            -- check for reset
            if tb_rst_n = '0' then
                next resp_loop; -- restart loop
            end if;

            -- capture signals at moment of output going high
            pulse_us_was    := to_integer(unsigned(tb_pulse_us)); -- capture pulse_us at moment of signal going high
            stop_sig_was    := tb_stop; -- capture stop_sig at moment of signal going high
            t_expected      := pulse_us_was * 1 us when tb_stop = '0' else G_STOP_US * 1 us; -- capture pulse us at moment of signal going high
            t_start         := now;

            -- detect false negative after a timeout
            if t_start - t_end > (10**6 / G_OUTPUT_HZ) * 1 us + C_TLRNCE then
                AffirmIf(FALSE,  C_TESTNAME & ": FAIL - false neg, gap=" & time'image(t_start - t_end));
                false_neg   := false_neg + 1;
                fail        := fail + 1;
            end if;

            -- wait for pulse to go low
            wait until tb_pwm_sig = '0' for t_expected + C_TLRNCE;

            -- check for reset
            if tb_rst_n = '0' then
                next resp_loop; -- restart loop
            end if;

            t_end   := now;
            t_width := t_end - t_start;

            -- pass
            if t_width >= t_expected - C_TLRNCE and t_width <= t_expected + C_TLRNCE then
                AffirmIf(TRUE,
                    C_TESTNAME & ": PASS - pwm_sig high for " &
                    integer'image(t_width / 1 us) &
                    " when pulse_us was " &
                    integer'image(pulse_us_was) &
                    ", stop_sig was " & 
                    std_logic'image(stop_sig_was)
                );
                pass := pass + 1;

            -- short
            elsif t_width < t_expected - C_TLRNCE then
                AffirmIf(FALSE, C_TESTNAME & ": FAIL - Short, pwm_sig high for " 
                    & integer'image((t_end - t_start) / 1 us) & 
                    " us when pulse_us was " & integer'image(pulse_us_was) & 
                    " us, gap=" & 
                    integer'image((t_expected - t_width) / 1 us)  &
                    ", stop_sig was " & 
                    std_logic'image(stop_sig_was)
                );
                short   := short + 1;
                fail    := fail + 1;

            -- long
            elsif t_width > t_expected + C_TLRNCE then
                AffirmIf(FALSE, C_TESTNAME & ": FAIL - Long, pwm_sig high for " & 
                    integer'image((t_end - t_start) / 1 us) & 
                    " when pulse_us was " & integer'image(pulse_us_was) & 
                    " us, gap=" & 
                    integer'image((t_expected - t_width) / 1 us) &
                    ", stop_sig was " & 
                    std_logic'image(stop_sig_was)
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