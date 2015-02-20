// Copyright (c) 2015 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

package Tb;

// A small testbench to drive the Enigma Simulator

// ================================================================
// imports from BSV lib

import Vector :: *;
import StmtFSM :: *;
import GetPut :: *;

// ================================================================
// imports for this project

import Enigma    :: *;
import HW_Enigma :: *;

// ================================================================
// A utility

function int vectorLength (Vector #(n, t) v) = fromInteger (valueOf (n));

// ================================================================

(* synthesize *)
module mkTb (Empty);
   // HW module instantiation
   ModelEnigma_IFC hw_ModelEnigma <- mkModelEnigma;

   // For sequential interaction with HW moodule
   Reg #(int) rg_j1 <- mkRegU;
   Reg #(int) rg_j2 <- mkRegU;

   mkAutoFSM (seq
		 displayVCharB ("Plaintext input:      ", pt_input, "\n\n");

		 // ----------------------------------------------------------------
		 $display ("Direct Cryptol-derived version");

		 // Encrypt
		 action
		    let ct = enigma  (modelEnigma, pt_input);
		    displayVCharB ("Cipher text output:   ", ct, "\n");
		    if (ct != ct_expected)
		       displayVCharB ("Expected ciphertext:  ", ct_expected, "\n");
		 endaction

		 // Decrypt
		 action
		    let pt_output = dEnigma (modelEnigma, ct_expected);
		    displayVCharB ("Plaintext output:     ", pt_output, "\n");
		    if (pt_output != pt_input)
		       displayVCharB ("Expected plaintext:   ", pt_input, "\n");
		 endaction

		 // ----------------------------------------------------------------
		 $display ("\nHW version (sequential input/output of text)");

		 // Encrypt (sequentially)
		 hw_ModelEnigma.reset;
		 $write ("Cipher text output:   ");
		 par
		    for (rg_j1 <= 0; rg_j1 < vectorLength (pt_input); rg_j1 <= rg_j1 + 1)
		       hw_ModelEnigma.request.put (pt_input [rg_j1]);

		    for (rg_j2 <= 0; rg_j2 < vectorLength (pt_input); rg_j2 <= rg_j2 + 1) action
		       let oc <- hw_ModelEnigma.response.get;
		       $write ("%c", oc);
		    endaction
		 endpar
		 $write ("\n");

		 // Decrypt (sequentially)
		 hw_ModelEnigma.reset;
		 $write ("Plaintext output:     ");
		 par
		    for (rg_j1 <= 0; rg_j1 < vectorLength (ct_expected); rg_j1 <= rg_j1 + 1)
		       hw_ModelEnigma.request.put (ct_expected [rg_j1]);

		    for (rg_j2 <= 0; rg_j2 < vectorLength (ct_expected); rg_j2 <= rg_j2 + 1) action
		       let oc <- hw_ModelEnigma.response.get;
		       $write ("%c", oc);
		    endaction
		 endpar
		 $write ("\n");
	      endseq);
endmodule

// ================================================================

endpackage
