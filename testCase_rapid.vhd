library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library osvvm;
--use osvvm.AlertLogPkg.all; -- used for logging and assertions
context osvvm.OsvvmContext;

entity testCase_rapid is
end entity;

architecture sim of testCase_rapid is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    constant C_CLK_HZ       : integer := 50_000_000;
    constant C_BITWIDTH     : integer := 32;
    constant C_PULSE_MODE   : boolean := true;
    constant C_GAP_US       : integer := 1;

    constant C_RST_PW_US    : integer := 1500;
    constant CLK_PERIOD     : time    := 20 ns;
    constant TOLERANCE      : time    := 2 * CLK_PERIOD;

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal tb_clk       : std_logic := '0';
    signal tb_rst_n     : std_logic := '1';
    signal tb_en        : std_logic := '0';
    signal tb_pulse_us  : std_logic_vector(C_BITWIDTH-1 downto 0) := (others => '0');
    signal tb_pwm_sig   : std_logic;

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
            C_PULSE_MODE    => C_PULSE_MODE,
            C_GAP_US        => C_GAP_US,
            C_RST_PW_US     => C_RST_PW_US
        )
        port map (
            pl_clk      => tb_clk,
            rst_n       => tb_rst_n,
            en          => tb_en,
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
        tb_en <= '0';
        tb_rst_n <= '1';
        set_pulse_us(tb_pulse_us, 0);
        RV.InitSeed (RV'instance_name);

        wait for 1 ms;

        ----------------------------------------------------------------
        -- Rapid Test
        ----------------------------------------------------------------
        t_us := 1000;
        tb_en <= '1';

        for i in 0 to 49 loop
            t_us := RV.RandInt(1100, 1900);
            Log("RAPID: TEST " & integer'image(i) & ": Pulse width set to " & integer'image(t_us), INFO);
            set_pulse_us(tb_pulse_us, t_us);
            
            wait for RV.RandInt(t_us/2, t_us * 2) * 1 us;

        end loop;
        wait for 1 ms;

        ----------------------------------------------------------------
        -- Done
        ----------------------------------------------------------------
        Log( "All tests completed", INFO);

        EndOfTestReports;
        stop;
        wait;
    end process;
    
    --------------------------------------------------------------------
    -- Response
    --------------------------------------------------------------------
    resp_proc : process
        variable t_us       : integer   := 0;
        variable t_start    : time      := 0 ns;
        variable t_end      : time      := 0 ns;
    begin
        ----------------------------------------------------------------
        -- Initial state
        ----------------------------------------------------------------
        wait for 1 ms;

        ----------------------------------------------------------------
        -- Test 2: Pulse Width 1000
        ----------------------------------------------------------------
        for i in 0 to 49 loop
            -- make sure output signal goes high at some point after fully enabled
            wait until tb_pwm_sig = '1';
            t_start := now;
            wait until tb_pwm_sig = '0';
            t_end := now;
            t_us := to_integer(unsigned(tb_pulse_us));
            if t_end - t_start >= t_us * 1 us - TOLERANCE and t_end - t_start <= t_us * 1 us + TOLERANCE then
                AffirmIf(TRUE,  "RAPID: TEST " & integer'image(i) & " PASSED, Signal stayed high for correct duration when pulse_us = " & integer'image(t_us));
            else
                AffirmIf(FALSE, "RAPID: TEST " & integer'image(i) & " FAILED, Signal stayed high for incorrect duration " & time'image(t_end - t_start) & " when pulse_us = " & integer'image(t_us));
            end if;
            wait for 0 ns;

        end loop;

        wait for 1 ms;
    end process;

end architecture;