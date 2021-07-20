class spi_host_tx_rx_vseq extends spi_host_base_vseq;
  `uvm_object_utils(spi_host_tx_rx_vseq)
  `uvm_object_new

  semaphore spi_host_atomic = new(1);

  spi_host_status_t status;

  virtual task body();
   // spi_host_init();
    wait_ready_for_command();
    start_spi_host_trans();

  endtask : body

  virtual task start_spi_host_trans();
    spi_host_regs.csaat = 0;
    spi_host_regs.csid = 0;
    //fork
    `uvm_info("SPI_DBG", $sformatf("REACHED!!!!"), UVM_LOW)
    //start_spi_agent_seq();
    `uvm_info("SPI_DBG", $sformatf("REACHED 1!!!!"), UVM_LOW)
    program_spi_host_regs();
    `uvm_info("SPI_DBG", $sformatf("REACHED 2!!!!"), UVM_LOW)    
    `uvm_info("SPI_DBG", $sformatf("REACHED 3!!!!"), UVM_LOW)
    wait_ready_for_command();
    wait_ready_for_command();
    csr_rd(.ptr(ral.status), .value(status));
    `uvm_info(`gfn, $sformatf("status is %b", status.active), UVM_LOW)
    write_spi_command(32'h00112233);
    write_spi_command(32'h44556677);
    write_spi_command(32'h8899aabb);
    write_spi_command(32'hccddeeff);
      program_command_reg();
    `uvm_info("SPI_DBG", $sformatf("REACHED END!!!!"), UVM_LOW)
    //      send_tx_trans();
    //      send_rx_trans();
    // join
    // wait for all accesses to complete
//    wait_no_outstanding_access();

    // read out status/intr_state CSRs to check
//    check_status_and_clear_intrs();

  endtask : start_spi_host_trans

  // sending tx requests to the agent
  virtual task send_tx_trans();
    if (spi_host_regs.direction inside {TxOnly, Bidir}) begin
      int byte_len = 0;
      bit [TL_DW-1:0] wr_word;
      bit [TL_AW-1:0] wr_align_addr = get_aligned_tl_addr();

      // iterate through the data_q and pop off words to write to tx_fifo
      `DV_CHECK_MEMBER_RANDOMIZE_WITH_FATAL(data_q,
                                            data_q.size() == spi_host_regs.len + 1;)
      `uvm_info(`gfn, $sformatf("\n  rxtx_vseq, write %0d bytes %p",
          data_q.size(), data_q), UVM_DEBUG)
      while (data_q.size() > 0) begin
        // get a word data which is programm to the data register
        wr_word = '0;
        byte_len = 0;
        for (int nbytes = 0; nbytes < TL_DBW; nbytes++) begin
          if (data_q.size() == 0) break;
          wr_word[8*nbytes +: 8] = data_q.pop_front();
          byte_len++;
        end
        if (byte_len > 0) begin
          `uvm_info(`gfn, $sformatf("\n  rxtx_vseq, write %0d bytes 0x%8x to tx_fifo",
              byte_len, wr_word), UVM_DEBUG)
          spi_host_atomic.get(1);
          wait_for_fifos_available(TxFifo);
          send_tl_access(.addr(wr_align_addr), .data(wr_word), .write(1'b1), .blocking(1'b1));
          spi_host_atomic.put(1);
          `DV_CHECK_MEMBER_RANDOMIZE_FATAL(tx_fifo_access_dly)
          cfg.clk_rst_vif.wait_clks(tx_fifo_access_dly);
        end
      end
    end
  endtask : send_tx_trans

  // get data responsed by the agent
  virtual task send_rx_trans();
    if (spi_host_regs.direction inside {RxOnly, Bidir}) begin
      bit [7:0]       rd_data[$];
      bit [7:0]       rd_byte[TL_DBW];
      bit [TL_DW-1:0] rd_word;
      int             byte_cnt = spi_host_regs.len + 1;
      bit [TL_AW-1:0] rd_align_addr = get_aligned_tl_addr();

      // TODO: temporaly disable due to bugs in the read path of rtl
      /*
      while (byte_cnt > 0) begin
        spi_host_atomic.get(1);
        wait_for_fifos_available(RxFifo);
        send_tl_access(.addr(rd_align_addr), .data(rd_word), .write(1'b0), .blocking(1'b1));
        spi_host_atomic.put(1);
        rd_byte = {<< 8 {rd_word}};
        foreach (rd_byte[i]) rd_data.push_back(rd_byte[i]);
        byte_cnt -= 4;
        `uvm_info(`gfn, $sformatf("\n  rxtx_vseq: receive data %p", rd_data), UVM_DEBUG)
        `DV_CHECK_MEMBER_RANDOMIZE_FATAL(rx_fifo_access_dly)
        cfg.clk_rst_vif.wait_clks(rx_fifo_access_dly);
      end
      */
    end
  endtask : send_rx_trans

  // send tl read/write request to a memory address (window type)
  virtual task send_tl_access(bit [TL_AW-1:0]  addr,
                              bit [TL_DW-1:0]  data,
                              bit              write,
                              bit [TL_DBW-1:0] mask = {TL_DBW{1'b1}},
                              bit              blocking = $urandom_range(0, 1));
    tl_access(.addr(addr), .write(write), .data(data), .mask(mask), .blocking(blocking));
    `uvm_info(`gfn, $sformatf("\n  rxtx_vseq, TL_%s to addr 0x%0x, data: 0x%8x, blk %b, mask %b",
        write ? "WRITE" : "READ", addr, data, blocking, mask), UVM_LOW)
  endtask : send_tl_access

  // start agent sequences
  virtual task start_spi_agent_seq();
    spi_device_seq m_spi_device_seq;

    `uvm_info("SPI_DBG", $sformatf("In agent task"), UVM_LOW)    

    `uvm_create_on(m_spi_device_seq, p_sequencer.spi_sequencer_h)
    `uvm_info(`gfn, "\n  rxtx_vseq: CREATED m_spi_device_seq", UVM_LOW)
    m_spi_device_seq.item_type = SpiTransNormal;
    m_spi_device_seq.byte_len  = spi_host_regs.len + 1;
    m_spi_device_seq.direction = spi_host_regs.direction;
    m_spi_device_seq.spi_mode  = spi_host_regs.speed;
    `uvm_info(`gfn, "\n  rxtx_vseq: SEND m_spi_device_seq", UVM_LOW)
    `uvm_info("SPI_DBG", $sformatf("mid agent task"), UVM_LOW)        
    `uvm_send(m_spi_device_seq);
    `uvm_info("SPI_DBG", $sformatf("end agent task"), UVM_LOW)        
  endtask : start_spi_agent_seq

endclass : spi_host_tx_rx_vseq
