// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// basic wake up sequence in place to verify that environment is hooked up correctly.
// static test that is running same data set every time


class aes_nist_vectors_vseq extends aes_base_vseq;
  `uvm_object_utils(aes_nist_vectors_vseq)

  `uvm_object_new


  parameter bit       ENCRYPT = 1'b0;
  parameter bit       DECRYPT = 1'b1;

  bit [3:0] [31:0]    plain_text       = 128'h00112233445566778899aabbccddeeff;
  bit [7:0] [31:0]    init_key[2]      = '{256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f, 256'h0};
  bit [3:0] [31:0]    nist_cypher[3]   = '{ 128'h69c4e0d86a7b0430d8cdb78070b4c55a,
                                            128'hdda97ca4864cdfe06eaf70a0ec0d7191,
                                            128'h8ea2b7ca516745bfeafc49904b496089 };
  bit [3:0] [31:0]    cypher_text;
  bit [3:0] [31:0]    decrypted_text;
  string              str="";
  bit                 do_b2b = 0;
  rand bit [2:0]       key_len;

  constraint c_key_len { key_len inside {3'b001,3'b010,3'b100}; }
 
  `include "nist_vectors.sv"

  task body();

    `uvm_info(`gfn, $sformatf("STARTING AES NIST VECTOR SEQUENCE"), UVM_LOW)


    `DV_CHECK_RANDOMIZE_FATAL(this)

    `uvm_info(`gfn, $sformatf(" \n\t ---|setting operation to encrypt"), UVM_MEDIUM)
    // set operation to encrypt
    set_operation(ENCRYPT);

    // transpose key
    init_key = '{ {<<8{init_key[0]}} ,  {<<8{init_key[1]}} };
    write_key(init_key, do_b2b);
    cfg.clk_rst_vif.wait_clks(20);

    `uvm_info(`gfn, $sformatf(" \n\t ---| ADDING PLAIN TEXT"), UVM_MEDIUM)
    // transpose input text
    plain_text = {<<8{plain_text}};
    add_data(plain_text, do_b2b);

    cfg.clk_rst_vif.wait_clks(20);
    // poll status register
    `uvm_info(`gfn, $sformatf("\n\t ---| Polling for data register %s",
                              ral.status.convert2string()), UVM_DEBUG)

    csr_spinwait(.ptr(ral.status.output_valid) , .exp_data(1'b1));
    read_data(cypher_text, do_b2b);

    cypher_text =  {<<8{cypher_text}};
    case (key_len)
      3'b001: begin
        if (nist_cypher[0] != cypher_text)
           `uvm_error(`gfn, $sformatf("Result does not match NIST for 128bit key \n %0h \n %0h",
            nist_cypher[0], cypher_text))
      end
      3'b010: begin
        if (nist_cypher[0] != cypher_text)
           `uvm_error(`gfn, $sformatf("Result does not match NIST for 192bit key \n %0h \n %0h",
            nist_cypher[1], cypher_text))
      end
      3'b100: begin
        if (nist_cypher[0] != cypher_text)
          `uvm_error(`gfn, $sformatf("Result does not match NIST for 192bit key \n %0h \n %0h",
            nist_cypher[1], cypher_text))
      end
    endcase // case (key_len)


    // read output
    cfg.clk_rst_vif.wait_clks(20);

    // set aes to decrypt
    set_operation(DECRYPT);
    cfg.clk_rst_vif.wait_clks(20);
    write_key(init_key, do_b2b);
    cfg.clk_rst_vif.wait_clks(20);
    `uvm_info(`gfn, $sformatf("\n\t ---| WRITING CYPHER TEXT"), UVM_MEDIUM)
    cypher_text =  {<<8{cypher_text}};
    add_data(cypher_text, do_b2b);


    `uvm_info(`gfn, $sformatf("\n\t ---| Polling for data %s", ral.status.convert2string()),
              UVM_DEBUG)

    cfg.clk_rst_vif.wait_clks(20);
    csr_spinwait(.ptr(ral.status.output_valid) , .exp_data(1'b1));
    read_data(decrypted_text, do_b2b);

    if(plain_text != decrypted_text) `uvm_fatal(`gfn, $sformatf("%s",str));


    `uvm_info(`gfn, $sformatf(" \n\t ---| YAY TEST PASSED |--- \n \t "), UVM_NONE)
  endtask : body
endclass : aes_nist_vectors_vseq
