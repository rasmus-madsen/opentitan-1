// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class spi_host_base_vseq extends cip_base_vseq #(
    .RAL_T               (spi_host_reg_block),
    .CFG_T               (spi_host_env_cfg),
    .COV_T               (spi_host_env_cov),
    .VIRTUAL_SEQUENCER_T (spi_host_virtual_sequencer)
  );
  `uvm_object_utils(spi_host_base_vseq)
  `uvm_object_new

  dv_base_reg           base_reg;

  // spi registers
  rand spi_host_regs_t  spi_host_regs;
  // random variables
  rand uint             num_runs;
  rand uint             tx_fifo_access_dly;
  rand uint             rx_fifo_access_dly;
  rand uint             clear_intr_dly;
  // FIFO: address used to access fifos
  rand bit [TL_AW:0]    fifo_base_addr;
  rand bit [7:0]        data_q[$];

  // constraints for simulation loops
  constraint num_trans_c {
    num_trans inside {[cfg.seq_cfg.host_spi_min_trans : cfg.seq_cfg.host_spi_max_trans]};
  }
  constraint num_runs_c {
    num_runs inside {[cfg.seq_cfg.host_spi_min_runs : cfg.seq_cfg.host_spi_max_runs]};
  }
  // contraints for fifos
  constraint fifo_base_addr_c {
    fifo_base_addr inside {[SPI_HOST_FIFO_START : SPI_HOST_FIFO_END]};
  }

  constraint intr_dly_c {
    clear_intr_dly inside {[cfg.seq_cfg.host_spi_min_dly : cfg.seq_cfg.host_spi_max_dly]};
  }
  constraint fifo_dly_c {
    rx_fifo_access_dly inside {[cfg.seq_cfg.host_spi_min_dly : cfg.seq_cfg.host_spi_max_dly]};
    tx_fifo_access_dly inside {[cfg.seq_cfg.host_spi_min_dly : cfg.seq_cfg.host_spi_max_dly]};
  }
  constraint spi_host_regs_c {
    // csid reg
      spi_host_regs.csid inside {[0 : SPI_HOST_NUM_CS-1]};
    // control reg
      spi_host_regs.tx_watermark dist {
        [0:7]   :/ 1,
        [8:15]  :/ 3,
        [16:31] :/ 2,
        [32:cfg.seq_cfg.host_spi_max_txwm] :/ 1
      };
      spi_host_regs.rx_watermark dist {
        [0:7]   :/ 1,
        [8:15]  :/ 3,
        [16:31] :/ 2,
        [32:cfg.seq_cfg.host_spi_max_rxwm] :/ 1
      };
      spi_host_regs.passthru dist {
        1'b0 :/ 1,
        1'b1 :/ 0   // TODO: currently disable passthru mode until specification is updated
      };
    // configopts regs
      foreach (spi_host_regs.cpol[i]) {
        spi_host_regs.cpol[i] dist {
          1'b0 :/ 1,     // TODO: hardcode for debug
          1'b1 :/ 0
        };
      }
      foreach (spi_host_regs.cpha[i]) {
        spi_host_regs.cpha[i] dist {
          1'b0 :/ 1,     // TODO: hardcode for debug
          1'b1 :/ 0
        };
      }
      foreach (spi_host_regs.csnlead[i]) {
        spi_host_regs.csnlead[i] inside {[cfg.seq_cfg.host_spi_min_csn_latency :
                                          cfg.seq_cfg.host_spi_max_csn_latency]};
      }
      foreach (spi_host_regs.csntrail[i]) {
        spi_host_regs.csntrail[i] inside {[cfg.seq_cfg.host_spi_min_csn_latency :
                                           cfg.seq_cfg.host_spi_max_csn_latency]};
      }
      foreach (spi_host_regs.csnidle[i]) {
        spi_host_regs.csnidle[i] inside {[cfg.seq_cfg.host_spi_min_csn_latency :
                                          cfg.seq_cfg.host_spi_max_csn_latency]};
      }
      foreach (spi_host_regs.clkdiv[i]) {
        spi_host_regs.clkdiv[i] inside {[cfg.seq_cfg.host_spi_min_clkdiv :
                                         cfg.seq_cfg.host_spi_max_clkdiv]};
      }
    // command reg
      //spi_host_regs.len inside {[cfg.seq_cfg.host_spi_min_len : cfg.seq_cfg.host_spi_max_len]};
      spi_host_regs.len inside {7};
      spi_host_regs.speed dist {
        Standard :/ 2,
        Dual     :/ 0,  // TODO: hardcode Dual=0 for debug
        Quad     :/ 0   // TODO: hardcode Dual=0 for debug
      };

      // TODO: temporaly forcing direction to TxOnly due to bugs in the read path of rtl
      if (spi_host_regs.speed == Standard) {
        spi_host_regs.direction dist {
          Dummy  :/ 1,
          Bidir  :/ 4,
          TxOnly :/ 0,
          RxOnly :/ 0
        };
      } else {
        spi_host_regs.direction dist {
          Dummy  :/ 1,
          TxOnly :/ 4,
          RxOnly :/ 4
        };
      }
  }

  virtual task pre_start();
    // sync monitor and scoreboard setting
    cfg.m_spi_agent_cfg.en_monitor_checks = cfg.en_scb;
    `uvm_info(`gfn, $sformatf("\n  base_vseq, %s monitor and scoreboard",
        cfg.en_scb ? "enable" : "disable"), UVM_DEBUG)
    num_runs.rand_mode(0);
    num_trans_c.constraint_mode(0);
    super.pre_start();
  endtask : pre_start

  virtual task initialization();
    wait(cfg.m_spi_agent_cfg.vif.rst_n);
    `uvm_info(`gfn, "\n  base_vseq, out of reset", UVM_LOW)
    spi_host_init();
    `uvm_info(`gfn, "\n  base_vseq, initialization is completed", UVM_LOW)
  endtask : initialization

  // setup basic spi_host features
  virtual task spi_host_init();
    bit [TL_DW-1:0] intr_state;

    // program sw_reset for spi_host dut
    program_spi_host_sw_reset();
    // enable then clear interrupts
    csr_wr(.ptr(ral.intr_enable), .value({TL_DW{1'b1}}));
    csr_rd(.ptr(ral.intr_state), .value(intr_state));
    csr_wr(.ptr(ral.intr_state), .value(intr_state));
  endtask : spi_host_init

  virtual task program_spi_host_sw_reset(int drain_cycles = SPI_HOST_RX_DEPTH);
    ral.control.sw_rst.set(1'b1);
    csr_update(ral.control);
    // make sure data completely drained from fifo then release reset
    wait_for_fifos_empty(AllFifos);
    ral.control.sw_rst.set(1'b0);
    csr_update(ral.control);
  endtask : program_spi_host_sw_reset

  virtual task program_spi_host_regs();
    // IMPORTANT: configopt regs must be programmed before command reg
    program_configopt_regs();
    program_control_reg();
    wait_ready_for_command();
    program_command_reg();
    update_spi_agent_regs();
  endtask : program_spi_host_regs

  virtual task program_csid_reg();
    // enable one of CS lines
    csr_wr(.ptr(ral.csid), .value(spi_host_regs.csid));
  endtask : program_csid_reg

  virtual task program_control_reg();
    ral.control.tx_watermark.set(spi_host_regs.tx_watermark);
    ral.control.rx_watermark.set(spi_host_regs.rx_watermark);
    ral.control.passthru.set(spi_host_regs.passthru);
    // activate spi_host dut
    ral.control.spien.set(1'b1);
    csr_update(ral.control);
  endtask : program_control_reg

  virtual task program_configopt_regs();
    // CONFIGOPTS register fields
    for (int i = 0; i < SPI_HOST_NUM_CS; i++) begin
      base_reg = (SPI_HOST_NUM_CS == 1) ? cfg.get_dv_base_reg_by_name("configopts") :
                                          cfg.get_dv_base_reg_by_name("configopts", i);
      cfg.set_dv_base_reg_field_by_name(base_reg, "cpol",     spi_host_regs.cpol[i], i);
      cfg.set_dv_base_reg_field_by_name(base_reg, "cpha",     spi_host_regs.cpha[i], i);
      cfg.set_dv_base_reg_field_by_name(base_reg, "fullcyc",  spi_host_regs.fullcyc[i], i);
      cfg.set_dv_base_reg_field_by_name(base_reg, "csnlead",  spi_host_regs.csnlead[i], i);
      cfg.set_dv_base_reg_field_by_name(base_reg, "csntrail", spi_host_regs.csntrail[i], i);
      cfg.set_dv_base_reg_field_by_name(base_reg, "csnidle",  spi_host_regs.csnidle[i], i);
      cfg.set_dv_base_reg_field_by_name(base_reg, "clkdiv",   spi_host_regs.clkdiv[i], i);
      csr_update(base_reg);
    end
  endtask : program_configopt_regs

  virtual task program_command_reg();
    // COMMAND register fields
    ral.command.direction.set(spi_host_regs.direction);
    ral.command.speed.set(spi_host_regs.speed);
    ral.command.csaat.set(spi_host_regs.csaat);
    ral.command.len.set(spi_host_regs.len);
    csr_update(ral.command);
  endtask : program_command_reg

  // read interrupts and randomly clear interrupts if set
  virtual task process_interrupts();
    bit [TL_DW-1:0] intr_state, intr_clear;

    // read interrupt
    csr_rd(.ptr(ral.intr_state), .value(intr_state));
    // clear interrupt if it is set
    `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(intr_clear,
                                       foreach (intr_clear[i]) {
                                         intr_state[i] -> intr_clear[i] == 1;
                                       })

    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(clear_intr_dly)
    cfg.clk_rst_vif.wait_clks(clear_intr_dly);
    csr_wr(.ptr(ral.intr_state), .value(intr_clear));
  endtask : process_interrupts

  // override apply_reset to handle core_reset domain
  virtual task apply_reset(string kind = "HARD");
    fork
      super.apply_reset(kind);
      begin
        if (kind == "HARD") begin
          cfg.clk_rst_core_vif.apply_reset();
        end
      end
    join
  endtask

  virtual task apply_resets_concurrently(int reset_duration_ps = 0);
    cfg.clk_rst_core_vif.drive_rst_pin(0);
    super.apply_resets_concurrently(cfg.clk_rst_core_vif.clk_period_ps);
    cfg.clk_rst_core_vif.drive_rst_pin(1);
  endtask // apply_resets_concurrently
  

  // override wait_for_reset to to handle core_reset domain
  virtual task wait_for_reset(string reset_kind = "HARD",
                              bit wait_for_assert = 1'b1,
                              bit wait_for_deassert = 1'b1);
    fork
      super.wait_for_reset(reset_kind, wait_for_assert, wait_for_deassert);
      begin
        if (wait_for_assert) begin
          `uvm_info(`gfn, "\n  base_vseq, waiting for core rst_n assertion...", UVM_DEBUG)
          @(negedge cfg.clk_rst_core_vif.rst_n);
        end
        if (wait_for_deassert) begin
          `uvm_info(`gfn, "\n  base_vseq, waiting for core rst_n de-assertion...", UVM_DEBUG)
          @(posedge cfg.clk_rst_core_vif.rst_n);
        end
        `uvm_info(`gfn, "\n  base_vseq, core wait_for_reset done", UVM_DEBUG)
      end
    join
  endtask : wait_for_reset

  // wait until fifos empty
  virtual task wait_for_fifos_empty(spi_host_fifo_e fifo = AllFifos);
    if (fifo == TxFifo || TxFifo == AllFifos) begin
      csr_spinwait(.ptr(ral.status.txempty), .exp_data(1'b1));
    end
    if (fifo == RxFifo || TxFifo == AllFifos) begin
      csr_spinwait(.ptr(ral.status.rxempty), .exp_data(1'b1));
    end
  endtask : wait_for_fifos_empty

  // wait dut ready for new command
  virtual task wait_ready_for_command();
    csr_spinwait(.ptr(ral.status.ready), .exp_data(1'b1));
    `uvm_info(`gfn, "\n  base_vseq, ready for programming new command", UVM_LOW)
  endtask : wait_ready_for_command

  // reads out the STATUS and INTR_STATE csrs so scb can check the status
  virtual task check_status_and_clear_intrs();
    bit [TL_DW-1:0] data;

    // read then clear interrupts
    csr_rd(.ptr(ral.intr_state), .value(data));
    csr_wr(.ptr(ral.intr_state), .value(data));
    // read status register
    csr_rd(.ptr(ral.status), .value(data));
  endtask : check_status_and_clear_intrs

  // wait until fifos has available entries to read/write
  virtual task wait_for_fifos_available(spi_host_fifo_e fifo = AllFifos);
    if (fifo == TxFifo || fifo == AllFifos) begin
      csr_spinwait(.ptr(ral.status.txfull), .exp_data(1'b0));
      `uvm_info(`gfn, $sformatf("\n  base_vseq: tx_fifo is not full"), UVM_LOW)
    end
    if (fifo == RxFifo || fifo == AllFifos) begin
      csr_spinwait(.ptr(ral.status.rxempty), .exp_data(1'b0));
      `uvm_info(`gfn, $sformatf("\n  base_vseq: rx_fifo is not empty"), UVM_LOW)
    end
  endtask

  // wait until no rx/tx_trans stalled
  virtual task wait_for_trans_complete(spi_host_fifo_e fifo = AllFifos);
    if (fifo == TxFifo || fifo == AllFifos) begin
      csr_spinwait(.ptr(ral.status.txstall), .exp_data(1'b0));
      `uvm_info(`gfn, $sformatf("\n  base_vseq: tx_trans is not stalled"), UVM_DEBUG)
    end
    if (fifo == RxFifo || fifo == AllFifos) begin
      csr_spinwait(.ptr(ral.status.rxstall), .exp_data(1'b0));
      `uvm_info(`gfn, $sformatf("\n  base_vseq: rx_trans is not stalled"), UVM_DEBUG)
    end
  endtask : wait_for_trans_complete

  // update spi_agent registers
  virtual function void update_spi_agent_regs();
    for (int i = 0; i < SPI_HOST_NUM_CS; i++) begin
      cfg.m_spi_agent_cfg.sck_polarity[i] = spi_host_regs.cpol[i];
      cfg.m_spi_agent_cfg.sck_phase[i]    = spi_host_regs.cpha[i];
      cfg.m_spi_agent_cfg.fullcyc[i]      = spi_host_regs.fullcyc[i];
      cfg.m_spi_agent_cfg.csnlead[i]      = spi_host_regs.csnlead[i];
    end
    cfg.m_spi_agent_cfg.csid              = spi_host_regs.csid;
    cfg.m_spi_agent_cfg.direction         = spi_host_regs.direction;
    cfg.m_spi_agent_cfg.spi_mode          = spi_host_regs.speed;
    cfg.m_spi_agent_cfg.csaat             = spi_host_regs.csaat;
    cfg.m_spi_agent_cfg.len               = spi_host_regs.len;

    print_spi_host_regs();
  endfunction : update_spi_agent_regs

  virtual function bit [TL_AW-1:0] get_aligned_tl_addr();
    bit [TL_AW-1:0] fifo_align_addr;

    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(fifo_base_addr)
    fifo_align_addr = ral.get_addr_from_offset(fifo_base_addr);
    `uvm_info(`gfn, $sformatf("\n  base_vseq, tl_base_addr:  0x%0x", fifo_base_addr), UVM_DEBUG)
    `uvm_info(`gfn, $sformatf("\n  base_vseq, tl_align_addr: 0x%0x", fifo_align_addr), UVM_DEBUG)
    return fifo_align_addr;
  endfunction : get_aligned_tl_addr

  // print the content of spi_host_regs[channel]
  virtual function void print_spi_host_regs(uint en_print = 1);
    if (en_print) begin
      string str = "";

      str = {str, "\n  base_vseq, values programed to the dut registers:"};
      str = {str, $sformatf("\n    csid         %0d", spi_host_regs.csid)};
      str = {str, $sformatf("\n    speed        %s",  spi_host_regs.speed.name())};
      str = {str, $sformatf("\n    direction    %s",  spi_host_regs.direction.name())};
      str = {str, $sformatf("\n    csaat        %b",  spi_host_regs.csaat)};
      str = {str, $sformatf("\n    len          %0d", spi_host_regs.len)};
      for (int i = 0; i < SPI_HOST_NUM_CS; i++) begin
        str = {str, $sformatf("\n    config[%0d]", i)};
        str = {str, $sformatf("\n      cpol       %b", spi_host_regs.cpol[i])};
        str = {str, $sformatf("\n      cpha       %b", spi_host_regs.cpha[i])};
        str = {str, $sformatf("\n      fullcyc    %b", spi_host_regs.fullcyc[i])};
        str = {str, $sformatf("\n      csnlead    %0d", spi_host_regs.csnlead[i])};
        str = {str, $sformatf("\n      csntrail   %0d", spi_host_regs.csntrail[i])};
        str = {str, $sformatf("\n      csnidle    %0d", spi_host_regs.csnidle[i])};
        str = {str, $sformatf("\n      clkdiv     %0d\n", spi_host_regs.clkdiv[i])};
      end
      `uvm_info(`gfn, str, UVM_LOW)
    end
  endfunction : print_spi_host_regs

  // phase alignment for resets signal of core and bus domain
  virtual task do_phase_align_reset(bit en_phase_align_reset = 1'b0);
    if (en_phase_align_reset) begin
      fork
        cfg.clk_rst_vif.wait_clks($urandom_range(5, 10));
        cfg.clk_rst_core_vif.wait_clks($urandom_range(5, 10));
      join
    end
  endtask : do_phase_align_reset


endclass : spi_host_base_vseq
