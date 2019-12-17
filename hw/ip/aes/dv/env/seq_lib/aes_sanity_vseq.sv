// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// basic sanity test vseq
  class aes_sanity_vseq extends aes_base_vseq;    
  `uvm_object_utils(aes_sanity_vseq)

  `uvm_object_new

  
    
  task body();
    
    `uvm_info(`gfn, $sformatf("STARTING AES SEQUENCE"), UVM_LOW);
    `DV_CHECK_RANDOMIZE_FATAL(this)
    
    aes_item = new();
    void'(aes_item.randomize());

    set_mode(ENCRYPT);
    // add key
    //write_key(aes_item.key);

    // add data
    add_data(aes_item.data_queue);
    // get cypher

    // set decrypt

    // add key

    // decrypt

    // check
    
        
    
      
  endtask : body  

endclass : aes_sanity_vseq


