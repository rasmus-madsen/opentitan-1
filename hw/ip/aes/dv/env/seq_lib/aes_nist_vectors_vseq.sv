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

  bit [3:0] [31:0]    plain_text[4];
  bit [7:0] [31:0]    init_key[2]      = '{256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f, 256'h0};
  bit [3:0] [31:0]    iv;
  bit [3:0] [31:0]    cipher_text[4];
  bit [3:0] [31:0]    decrypted_text;
  string              str="";
  bit                 do_b2b = 0;
  int                 num_vec = 0;
  `include "nist_vectors.sv"

  nist_vector_t nist_vectors[];

  function string vector2string(nist_vector_t vector);
    string            str ="";
    str = $sformatf("\n ----| NIST Vector | ----");
    str = $sformatf("%s \n Mode: %s", str, vector.mode.name);
    str = $sformatf("%s \n Key Len: %s", str, vector.key_len.name);
    str = $sformatf("%s \n Key: %0h", str, vector.key);
    str = $sformatf("%s \n Iv: %0h", str, vector.iv);
    str = $sformatf("%s \n plaintext: %0h", str, vector.plain_text[0]);
    str = $sformatf("%s \n plaintext: %0h", str, vector.plain_text[1]);
    str = $sformatf("%s \n plaintext: %0h", str, vector.plain_text[2]);
    str = $sformatf("%s \n plaintext: %0h", str, vector.plain_text[3]);
    str = $sformatf("%s \n ciphertext: %0h", str, vector.cipher_text[0]);
    str = $sformatf("%s \n ciphertext: %0h", str, vector.cipher_text[1]);
    str = $sformatf("%s \n ciphertext: %0h", str, vector.cipher_text[2]);
    str = $sformatf("%s \n ciphertext: %0h", str, vector.cipher_text[3]);    
    return str;
  endfunction // vector2string
  
  

  task body();

    `uvm_info(`gfn, $sformatf("STARTING AES NIST VECTOR SEQUENCE"), UVM_LOW)
    num_vec = get_num_vectors();
    nist_vectors = new[num_vec];
    
    void'(get_vectors(nist_vectors));
    `uvm_info(`gfn, $sformatf("size of array %d", nist_vectors.size()), UVM_LOW)

    `DV_CHECK_RANDOMIZE_FATAL(this)

    foreach (nist_vectors[i]) begin
      // wait for dut idle
      csr_spinwait(.ptr(ral.status.idle) , .exp_data(1'b1));
      `uvm_info(`gfn, $sformatf("%s", vector2string(nist_vectors[i]) ), UVM_LOW)
      `uvm_info(`gfn, $sformatf(" \n\t ---|setting operation to encrypt"), UVM_MEDIUM)
      // set operation to encrypt
      set_operation(ENCRYPT);
      //set key_leng
      set_key_len(nist_vectors[i].key_len);
      set_mode(nist_vectors[i].mode);
      // transpose key
      init_key = '{ {<<8{nist_vectors[i].key}} ,  256'h0 };
      write_key(init_key, do_b2b);
      if (nist_vectors[i].mode != AES_ECB) begin
        iv = {<<8{nist_vectors[i].iv}};
        write_iv(iv, do_b2b);
      end

      `uvm_info(`gfn, $sformatf(" \n\t ---| ADDING PLAIN TEXT"), UVM_MEDIUM)
      
      foreach (nist_vectors[i].plain_text[n]) begin
        csr_spinwait(.ptr(ral.status.input_ready) , .exp_data(1'b1));
        // transpose input text
        plain_text[n] = {<<8{nist_vectors[i].plain_text[n]}};
        add_data(plain_text[n], do_b2b);
     
        // poll status register
        `uvm_info(`gfn, $sformatf("\n\t ---| Polling for data register %s",
                                ral.status.convert2string()), UVM_DEBUG)

        csr_spinwait(.ptr(ral.status.output_valid) , .exp_data(1'b1));
        read_data(cipher_text[n], do_b2b);
      end
      foreach (nist_vectors[i].plain_text[n]) begin
      
        cipher_text[n] =  {<<8{cipher_text[n]}};
      `uvm_info(`gfn, $sformatf("calculated cipher %0h",cipher_text[n]), UVM_LOW)
        if (cipher_text[n] != nist_vectors[i].cipher_text[n]) begin
        `uvm_error(`gfn, $sformatf("Result does not match NIST for vector[%d][%d], \n nist: %0h \n output: %0h", i,n,
                                   nist_vectors[i].cipher_text[n], cipher_text[n]))
        end
    end
    
      
 


//     // read output
//     cfg.clk_rst_vif.wait_clks(20);
//
//     // set aes to decrypt
//     set_operation(DECRYPT);
//     cfg.clk_rst_vif.wait_clks(20);
//     write_key(init_key, do_b2b);
//     cfg.clk_rst_vif.wait_clks(20);
//     `uvm_info(`gfn, $sformatf("\n\t ---| WRITING CIPHER TEXT"), UVM_MEDIUM)
//     cipher_text =  {<<8{cipher_text}};
//     add_data(cipher_text, do_b2b);
//
//
//     `uvm_info(`gfn, $sformatf("\n\t ---| Polling for data %s", ral.status.convert2string()),
//               UVM_DEBUG)
//
//     cfg.clk_rst_vif.wait_clks(20);
//     csr_spinwait(.ptr(ral.status.output_valid) , .exp_data(1'b1));
//     read_data(decrypted_text, do_b2b);
//
//     if(plain_text != decrypted_text) `uvm_fatal(`gfn, $sformatf("%s",str));
//   end // foreach ({nist_vectors[i].plain_text[n])
      
      
    end // foreach (nist_vectors[i])
    

    `uvm_info(`gfn, $sformatf(" \n\t ---| YAY TEST PASSED |--- \n \t "), UVM_NONE)
  endtask : body
endclass : aes_nist_vectors_vseq
