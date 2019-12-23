// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
package aes_seq_item_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import aes_reg_pkg::*;
  
  class aes_seq_item extends uvm_sequence_item;
  
  
    // for config object
    int    DATA_LEN_MIN = 128;                                              // min number of data bytes
    int    DATA_LEN_MAX = 128;                                              // Max number of data bytes     
  
    //end for config object
  
    // randomized values //
    rand bit                                 mode;                          // 0: encrypt, 1: decrypt
    rand bit                                 man_trigger;                   // 0: auto start, 1: wait for start
    rand bit                                 allow_data_ovrwrt;             // 0: output data cannot be overwritten 1: new output will overwrite old output even if not read.
    rand bit                   [31:0]        data_len;                      // lenth of plaintext / cypher
    rand bit                   [7:0]         key_size;                      // key len 0: 128, 1: 192, 2: 256 3: NOT VALID
    rand aes_reg2hw_key_mreg_t [7:0]         key;                           // 256 bit key (8x32 bit)
    rand bit                   [31:0]        data_in_queue[$];              // data queue to hold the randomized data  
    rand bit                   [31:0]        aes_data;                      // randomized data to add to queue


    // fixed variables //
    bit                         [3:0]       data_vld = 4'b0;                // indicated which words has data
    bit                   [3:0][31:0]       data_in;                        // used by the checker 
    bit                   [3:0][31:0]       data_out;                       // used by the checker
    bit                        [31:0]       data_out_queue[$];              // used to store output data

    function new( string name="aes_sequence_item");
      super.new(name);
    endfunction
    
    
    // contraints //
    constraint c_data {
      solve data_len before data_in_queue;
      data_len inside { [DATA_LEN_MIN: DATA_LEN_MAX] };
      data_in_queue.size() == data_len >> 2;
    }
    constraint c_key_size {key_size inside { 128, 192, 256 }; }
   
    constraint c_mode_reg {mode == 1; man_trigger == 0; allow_data_ovrwrt == 0; }

      
    function void post_randomize();
      mask_data();
    endfunction
    
     
    // function that makes sure that the queue hold the correct number of bytes
    // and that the last Qword is 0 padded if not full.
    function void mask_data();     
      case(data_len[1:0])
        2'b01: aes_data[31:8]  = 24'h0 ;
        2'b10: aes_data[31:16] = 16'h0 ;
        2'b11: aes_data[31:24] =  8'h0 ;
      endcase
     
      if(data_len > 4 && (data_len[1:0] != 2'b00)) begin
        data_in_queue.push_front(aes_data);
      end else begin
        data_in_queue.pop_front;
        data_in_queue.push_front(aes_data);
      end
      
    endfunction

    function bit add2output( logic [31:0] data );
      data_out_queue.push_back(data);
      return 1;      
    endfunction

    virtual function void do_copy(uvm_object rhs);

      aes_seq_item rhs_;
      
      if(!$cast(rhs_,rhs) ) begin
        uvm_report_error("do_copy:", "acst failed");
        return;
      end
      super.do_copy(rhs);
      mode = rhs_.mode;
      data_in_queue = rhs_.data_in_queue;
      key = rhs_.key;
      data_out_queue = rhs_.data_out_queue;
    endfunction // copy
    
  // do compare //
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
  
    aes_seq_item rhs_;
  
    if(!$cast(rhs_,rhs))begin
      return 0; // compare failed because object is not of sequence item type
    end

  return(super.do_compare(rhs,comparer) &&
    (mode           == rhs_.mode) &&
    (data_in_queue  == rhs_.data_in_queue) &&
    (key            == rhs_.key) &&
    (data_out_queue == rhs_.data_out_queue) );           
             
  endfunction // compare
  
  
  // convert to string //
  virtual function string convert2string();
   string str;
    str = super.convert2string();
    str = {str,  $psprintf("\t\n ----| AES SEQUENCE ITEM |----\t \n\t ----| REST IS TBD") };
    return str;
  endfunction // conver2string

 
  `uvm_object_utils(aes_seq_item);
    
  
  
  endclass
endpackage
  

    


