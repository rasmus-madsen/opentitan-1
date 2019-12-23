// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
import aes_seq_item_pkg::*;
import aes_model_dpi_pkg::*;

class aes_scoreboard extends cip_base_scoreboard #(
    .CFG_T(aes_env_cfg),
    .RAL_T(aes_reg_block),
    .COV_T(aes_env_cov)
  );
  `uvm_component_utils(aes_scoreboard)

   `uvm_component_new

  // local variables
  aes_seq_item dut_item;
  aes_seq_item ref_item;
  // TLM agent fifos

  // local queues to hold incoming packets pending comparison
  mailbox #(aes_seq_item) dut_fifo;                                   // all incoming TL transactions will be written to this one
  mailbox #(aes_seq_item) ref_fifo;                                   // this will be a clone of the above before the result has been calculated by the dut!

 
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    dut_fifo = new();
    ref_fifo = new();
    dut_item = new("dut_item");
    ref_item = new("ref_item");
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
     fork
     // compare();  
    join_none
  endtask

  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel = DataChannel);
    uvm_reg csr;
    bit do_read_check = 1'b0;
    bit write = item.is_write();
    uvm_reg_addr_t csr_addr = get_normalized_addr(item.a_addr);

    super.process_tl_access(item, channel);
    if (is_tl_err_exp || is_tl_unmapped_addr) return;

    // if access was to a valid csr, get the csr handle
    if (csr_addr inside {cfg.csr_addrs}) begin

      csr = ral.default_map.get_reg_by_offset(csr_addr);

      `DV_CHECK_NE_FATAL(csr, null)
    end else begin
      `uvm_fatal(`gfn, $sformatf("Access unexpected addr 0x%0h", csr_addr))
    end

    if (channel == AddrChannel) begin
      // if incoming access is a write to a valid csr, then make updates right away
      if (write) begin
        void'(csr.predict(.value(item.a_data), .kind(UVM_PREDICT_WRITE), .be(item.a_mask)));        
      end
      case (csr.get_name())
        // add individual case item for each csr
        "ctrl": begin
          {dut_item.allow_data_ovrwrt, dut_item.man_trigger,dut_item.key_size, dut_item.mode } = item.a_data[5:0];
          `uvm_info(`gfn, $sformatf("\n\t ----| received write to mode reg %d %d %d %d", dut_item.mode, dut_item.key_size, dut_item.man_trigger, dut_item.allow_data_ovrwrt ), UVM_LOW)
        end        
        "key0": begin
          dut_item.key[0].q = item.a_data;  
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h",csr.get_name(), item.a_addr, item.a_data), UVM_LOW)
        end
        "key1": begin
          dut_item.key[1].q = item.a_data;
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h IS_WRITE %b",csr.get_name(), item.a_addr, item.a_data, write), UVM_LOW)
        end
        "key2": begin
          dut_item.key[2].q = item.a_data;          
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h",csr.get_name(), item.a_addr, item.a_data), UVM_LOW)
        end
        "key3": begin
          dut_item.key[3].q = item.a_data;
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h",csr.get_name(), item.a_addr, item.a_data), UVM_LOW)
        end
        "key4": begin
          dut_item.key[4].q = item.a_data;
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h",csr.get_name(), item.a_addr, item.a_data), UVM_LOW)
        end
        "key5": begin
          dut_item.key[5].q = item.a_data;
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h",csr.get_name(), item.a_addr, item.a_data), UVM_LOW)
        end
        "key6": begin
          dut_item.key[6].q = item.a_data;
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h",csr.get_name(), item.a_addr, item.a_data), UVM_LOW)
        end
        "key7": begin
          dut_item.key[7].q = item.a_data;
          `uvm_info(`gfn, $sformatf("\n\t ----| SAW WRITE REGISTER %s TO addr %h of data %02h",csr.get_name(), item.a_addr, item.a_data), UVM_LOW)           
        end

        "data_in0" :begin
          dut_item.data_in[0] = item.a_data;
          dut_item.data_vld[0] = 1;
          if(!dut_item.man_trigger && (& dut_item.data_vld)) begin
            $cast(ref_item, dut_item.clone());
            ref_fifo.put(ref_item);
          end
        end

        "data_in1" :begin
          dut_item.data_in[1] = item.a_data;
          dut_item.data_vld[1] = 1;
          if(!dut_item.man_trigger && (& dut_item.data_vld)) begin
            $cast(ref_item, dut_item.clone());
            ref_fifo.put(ref_item);
          end
        end

        "data_in2" :begin
          dut_item.data_in[2] = item.a_data;
          dut_item.data_vld[2] = 1;          
          if(!dut_item.man_trigger && (& dut_item.data_vld)) begin
            $cast(ref_item, dut_item.clone());
            ref_fifo.put(ref_item);
          end
        end
        
        "data_in3": begin
          dut_item.data_in[3] = item.a_data;
          dut_item.data_vld[3] = 1;          
          if(!dut_item.man_trigger&& (& dut_item.data_vld)) begin
            $cast(ref_item, dut_item.clone());
            `uvm_info(`gfn, $sformatf("\t\n ----| ADDING TO REF FIFO"), UVM_LOW)
            ref_fifo.put(ref_item);
          end
        end
        
        "trigger": begin
          if(item.a_data[0]) begin
            $cast(ref_item, dut_item.clone());
            ref_fifo.put(ref_item);
          end     
        end

        "status": begin
        end
        
        
        
        

        default: begin
         // DO nothing- trying to write to a read only register

        end
      endcase


      // process the csr req
      // for write, update local variable and fifo at address phase
      // for read, update predication at address phase and compare at data phase
      

      // On reads, if do_read_check, is set, then check mirrored_value against item.d_data
      `uvm_info(`gfn, $sformatf("\n\t ---| channel  %h", channel), UVM_LOW)
      if (!write && channel == DataChannel) begin
        if (do_read_check) begin
          `DV_CHECK_EQ(csr.get_mirrored_value(), item.d_data,
                       $sformatf("reg name: %0s", csr.get_full_name()))
        end
        void'(csr.predict(.value(item.d_data), .kind(UVM_PREDICT_READ)));
        `uvm_info(`gfn, $sformatf("\n\t ----| SAW READ - %s data %02h",csr.get_name(),  item.d_data), UVM_LOW)

        case (csr.get_name())
          "data_out0": begin
           dut_item.data_in[0] =   item.d_data;
          end
          "data_out1": begin
            dut_item.data_in[1] =   item.d_data;
          end
          "data_out2": begin
            dut_item.data_in[2] =   item.d_data;
          end
          "data_out3": begin
            dut_item.data_in[3] =   item.d_data;
            `uvm_info(`gfn, $sformatf("\n\t ----| ADDING TO DUT FIFO"), UVM_LOW)
            dut_fifo.put(dut_item);
          end
          
        endcase      
      end
      
    end
  endtask


  virtual task compare();
    process_objections(1'b1);      
    forever begin
      aes_seq_item rtl_item;
      aes_seq_item c_item;
      bit [127:0] calc_data;

      `uvm_info(`gfn, $sformatf("\n\t ----| TRYING to get iten "), UVM_LOW)
      dut_fifo.get(rtl_item);
      ref_fifo.get(c_item );



      

      aes_crypt_dpi( 1'b0, rtl_item.mode, rtl_item.key_size, rtl_item.key, rtl_item.data_in, rtl_item.data_out);

      `uvm_info(`gfn, $sformatf("\n\t ----|   DATA OUTPUT \t\t  |----"), UVM_LOW)
      foreach(rtl_item.data_out[i]) begin
        `uvm_info(`gfn, $sformatf("\n\t ----| [%d] \t %02h \t %02h |----", i, rtl_item.data_out[i], c_item.data_out[i]), UVM_LOW)    
      end
      process_objections(1'b0);  
    end
    
  endtask
  

  virtual function void reset(string kind = "HARD");
    super.reset(kind);
    // reset local fifos queues and variables
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    // post test checks - ensure that all local fifos and queues are empty
  endfunction

endclass
