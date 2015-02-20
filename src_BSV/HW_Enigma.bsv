// Copyright (c) 2015 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil (Bluespec, Inc.)

package HW_Enigma;

// ================================================================
// This is a demonstration that the pure functional Cryptol-derived
// code in Enigma.bsv is directly synthesizable to hardware (HW) by
// the 'bsc' compiler.  It is not intended to demonstrate high-quality
// hardware, just that it is possible to get a first HW version easily
// from the original specification code, which can then serve as a
// first step in refinement to high quality hardware.  Good quality
// hardware requires careful attention to ARCHITECTURE.  Even after
// refinement, the core computation functions will remain unchanged
// from the spec.

// The main consideration for HW is that we cannot pass/return
// arbitrary-length strings (plaintext, ciphertext), as we do in the
// 'enigma' and 'dEnigma' functions.  Instead, the interface accepts
// and returns one character at a time, and the state of the machine
// is remembered between characters (in register 'rg_m').

// Further, once we start refining to good quality hardware, there may
// be some cycles of latency between receiving an input character and
// delivering the corresponding output character, so the interface
// becomes "split-phase" with request/response parts.

// A 'reset' method resets the machine to its initial configuration of
// plugboard, rotors, reflector, and rotor positions.

// ================================================================
// imports from BSV lib

import Vector :: *;
import GetPut :: *;
import FIFOF  :: *;

// ================================================================
// Import the Enigma functions

import Enigma :: *;

// ================================================================
// The hardware module interface

interface ModelEnigma_IFC;
   method Action reset;
   interface Put #(CharB) request;
   interface Get #(CharB) response;
endinterface

// ================================================================
// The hardware module

(* synthesize *)
module mkModelEnigma (ModelEnigma_IFC);

   // ----------------
   // LOCAL STATE

   FIFOF #(CharB) fifo_in  <- mkFIFOF;
   FIFOF #(CharB) fifo_out <- mkFIFOF;

   // The Enigma machine
   Reg #(Enigma #(3)) rg_m <- mkRegU;

   // Just for fun: for viewing in waveforms
   Vector #(3, Reg #(Bool)) rotor_clicks <- replicateM (mkReg (False));

   // ----------------
   // BEHAVIOR

   rule rl_process_char;
      let c0 = fifo_in.first; fifo_in.deq;

      // single-char version of 'enigma()/dEnigma()' functions above
      Vector #(3, Rotor) rs = rg_m.rotors;
      match { .rs_prime, .c5 } = enigmaLoop (rg_m.plugboard, rs, rg_m.reflector, c0);
      fifo_out.enq (c5);

      // Update state of rotors
      rg_m <= Enigma {plugboard: rg_m.plugboard,
		      rotors:    rs_prime,
		      reflector: rg_m.reflector};

      // Just for fun: record rotor clicks so we can see them in waveforms
      // Note: this is convenient, but is NOT an efficient way to do it!
      Vector #(3, Bool) clicks = zipWith (\/=  , rs, rs_prime);
      writeVReg (rotor_clicks, clicks);
   endrule

   // ----------------
   // INTERFACE

   method Action reset;
      rg_m <= modelEnigma;
      writeVReg (rotor_clicks, replicate (False));
   endmethod

   interface request = toPut (fifo_in);
   interface response = toGet (fifo_out);
endmodule

// ================================================================

endpackage
