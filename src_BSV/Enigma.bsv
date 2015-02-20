// Copyright (c) 2015 Bluespec, Inc.  All Rights Reserved
// Except: Cryptol code (in comments) copyright Galois, Inc.

// BSV code author: Rishiyur S. Nikhil (Bluespec, Inc.)
// Cryptol code: from Cryptol book (see below)

//CR 8    module Enigma where

package Enigma;

// ================================================================
// This is a manual transcription into BSV of the Cryptol Enigma Simulator
// described in Chapter 4 and Appendix C of the book:
//    Programming Cryptol (Cryptol: The Language of Cryptography)
//    Levent Erkök, Dylan McNamee, Joe Kiniry, Iavor Diatchki and John Launchbury
//    Galois, Inc., 2010-2014
// The book is distributed in PDF form at:    http://cryptol.net/

// The simulator models the German Enigma cryptography machine made
// famous by its role in World War II, and the British successes in
// cracking the code (led by Alan Turing).

// Lines beginning with '//CR' are cut-and-pasted from the Cryptol
// program listing given in the book's Appendix C, so that you can see
// the almost 1-to-1 transcription into BSV.

//CR 1    // Cryptol Enigma Simulator
//CR 2    // Copyright (c) 2010-2013, Galois Inc.
//CR 3    // www.cryptol.net
//CR 4    // You can freely use this source code for educational purposes.

// ================================================================
// imports from BSV lib

import List :: *;
import Vector :: *;
import BuildVector :: *;

// ================================================================
//CR 5
//CR 6    // Helper synonyms:
//CR 7    // type Char        = [8]

typedef Bit #(8)  CharB;    // Note: different from BSV's 'Char' type

// The BSV types Char and String are not in the Bits typeclass, and
// therefore have no hardware representation.  So, to demonstrate
// synthesizability the BSV code uses CharB instead of Char; CharB is
// in the Bits typeclass.  However, for external testbench drivers
// it's still useful to use String and Char, so the following are
// convenience functions for conversion.  These are not used in the
// synthesized parts of the code.

function CharB charToCharB (Char c) = fromInteger (charToInteger (c));

function Vector #(n, CharB) stringToVCharB (String s);
   return map (fromInteger,
	       map (charToInteger,
		    toVector (stringToCharList (s))));
endfunction

function Action displayVCharB (String pre, Vector #(n, CharB) vcharb, String post);
   action
      $write ("%s", pre);
      for (Integer j = 0; j < valueOf (n); j = j + 1)
	 $write ("%c", vcharb [j]);
      $write ("%s", post);
   endaction
endfunction   

// ================================================================

//CR 8    module Enigma where  [moved to top of this file, cf. 'package']
//CR 9
//CR 10    type Permutation = String 26

typedef Vector #(26, CharB)                 Permutation;

//CR 11
//CR 12    // Enigma components:
//CR 13    type Plugboard  = Permutation
//CR 14    type Rotor      = [26](Char, Bit)
//CR 15    type Reflector  = Permutation

typedef Permutation                          Plugboard;
typedef Vector #(26, Tuple2 #(CharB, Bool))  Rotor;
typedef Permutation                          Reflector;

//CR 16
//CR 17    // An enigma machine with n rotors:
//CR 18    type Enigma n   = { plugboard : Plugboard,
//CR 19                        rotors    : [n]Rotor,
//CR 20                        reflector : Reflector
//CR 21                      }

typedef struct {
   Plugboard           plugboard;
   Vector #(n, Rotor)  rotors;
   Reflector           reflector;
   } Enigma #(numeric type n)
   deriving (Bits, FShow);

//CR 22    
//CR 23    // Check membership in a sequence:
//CR 24    elem : {a, b} (fin 0, fin a, Cmp b) => (b, [a]b) -> Bit
//CR 25    elem (x, xs) = matches ! 0
//CR 26      where matches = [False] # [ m || (x == e) | e <- xs
//CR 27                                                | m <- matches
//CR 28                                ]

// 'elem' is already defined in BSV's Vector library:
//    function Bool elem (element_type x,
//                        Vector#(vsize,element_type) vect )
//        provisos (Eq#(element_type));

//CR 29    // Inverting a permutation lookup:
//CR 30    invSubst : (Permutation, Char) -> Char
//CR 31    invSubst (key, c) = candidates ! 0
//CR 32      where candidates = [0] # [ if c == k then a else p
//CR 33                               | k <- key
//CR 34                               | a <- ['A' .. 'Z']
//CR 35                               | p <- candidates
//CR 36                               ]

function CharB invSubst (Permutation key, CharB c);
   CharB p = ?;    // Note: don't care
   for (Integer j = 0; j < 26; j = j + 1) begin
      let k = key [j];
      let a = fromInteger (j) + charToCharB ("A");
      p = (c == k) ? a : p;
   end
   return p;
endfunction

//CR 37
//CR 38    // Constructing a rotor    
//CR 39    mkRotor : {n} (fin n) => (Permutation, String n) -> Rotor    
//CR 40    mkRotor (perm, notchLocations) = [ (p, elem (p, notchLocations))
//CR 41                                     | p <- perm    
//CR 42                                     ]

// Note: mkRotor is only for Enigma construction, not operation, so
// it's ok to involve String, a non-hardware type

function Rotor mkRotor (Permutation perm, String notchLocations);
   function Tuple2 #(CharB, Bool) f_addNotch (CharB ch)
      = tuple2 (ch, List::elem (ch, List::map (charToCharB, stringToCharList (notchLocations))));
   return map (f_addNotch, perm);
endfunction

//CR 43
//CR 44    // Action of a single rotor on a character    
//CR 45    // Note that we encrypt and then rotate, if necessary    
//CR 46    scramble : (Bit, Char, Rotor) -> (Bit, Char, Rotor)    
//CR 47    scramble (rotate, c, rotor) = (notch, c', rotor')
//CR 48      where
//CR 49        (c', _)    = rotor @ (c - 'A')    
//CR 50        (_, notch) = rotor @ 0    
//CR 51        rotor'     = if rotate then rotor <<< 1 else rotor    

function Tuple3 #(Bool, CharB, Rotor) scramble (Bool rot, CharB c, Rotor rotor);
   match { .c_prime, .* }    = rotor [c - charToCharB ("A")];
   match { .*, .notch}       = rotor [0];
   let rotor_prime           = rot ? rotate (rotor) : rotor;
   return tuple3 (notch, c_prime, rotor_prime);
endfunction

//CR 52
//CR 53    // Connecting rotors in a sequence
//CR 54    joinRotors : {n} (fin n) => ([n]Rotor, Char) -> ([n]Rotor, Char)
//CR 55    joinRotors (rotors, inputChar) = (rotors', outputChar)
//CR 56      where
//CR 57        initRotor = mkRotor (['A' .. 'Z'], [])
//CR 58        ncrs : [n+1](Bit, [8], Rotor)
//CR 59        ncrs = [(True, inputChar, initRotor)]
//CR 60                   # [ scramble (notch, char, r)
//CR 61                     | r <- rotors
//CR 62                     | (notch, char, rotor') <- ncrs
//CR 63                     ]
//CR 64        rotors' = tail [ r | (_, _, r) <- ncrs ]
//CR 65        (_, outputChar, _) = ncrs ! 0

function Tuple2 #(Vector #(n, Rotor), CharB) joinRotors (Vector #(n, Rotor) rotors, CharB inputChar);
   function CharB fn_ch_j (Integer j) = fromInteger (j) + charToCharB ("A");
   // Rotor initRotor = mkRotor (genWith (fn_ch_j), "");    // The Cryptol version
   Rotor initRotor = ?;                                     // Unspecified, since we don't use it
   Vector #(TAdd #(n,1), Tuple3 #(Bool, CharB, Rotor)) ncrs;
   ncrs [0] = tuple3 (True, inputChar, initRotor);
   for (Integer j = 1; j <= valueOf (n); j = j + 1) begin
      let r = rotors [j-1];
      match { .notch, .char, .* } = ncrs [j-1];
      ncrs [j] = scramble (notch, char, r);
   end
   let rotors_prime = tail (map (tpl_3, ncrs));
   let outputChar = tpl_2 (ncrs [valueOf (n)]);
   return tuple2 (rotors_prime, outputChar);
endfunction

//CR 66
//CR 67    // Following the signal through a single rotor, forward and backward
//CR 68    substFwd, substBwd : (Permutation, Char) -> Char
//CR 69    substFwd (perm, c) = perm @ (c - 'A')
//CR 70    substBwd (perm, c) = invSubst (perm, c)

function CharB substFwd (Permutation perm, CharB c) = perm [c - charToCharB ("A")];
function CharB substBwd (Permutation perm, CharB c) = invSubst (perm, c);

//CR 71    // Route the signal back from the reflector, chase through rotors
//CR 72    backSignal : {n} (fin n) => ([n]Rotor, Char) -> Char
//CR 73    backSignal (rotors, inputChar) = cs ! 0
//CR 74      where cs = [inputChar] # [ substBwd ([ p | (p, _) <- r ], c)
//CR 75                               | r <- reverse rotors
//CR 76                               | c <- cs
//CR 77                               ]

function CharB backSignal (Vector #(n, Rotor) rotors, CharB inputChar);
   CharB c = inputChar;
   for (Integer j = 0; j < valueOf (n); j = j + 1) begin
      let r = reverse (rotors) [j];
      c = substBwd (map (tpl_1, r), c);
   end
   return c;
endfunction

//CR 78
//CR 79    // The full enigma loop, from keyboard to lamps:    
//CR 80    // The signal goes through the plugboard, rotors, and the reflector,    
//CR 81    // then goes back through the sequence in reverse, out of the    
//CR 82    // plugboard and to the lamps    
//CR 83    enigmaLoop : {n} (fin n) => (Plugboard, [n]Rotor, Reflector, Char) -> ([n]Rotor, Char)    
//CR 84    enigmaLoop (pboard, rotors, refl, c0) = (rotors', c5)
//CR 85      where    
//CR 86        c1 = substFwd (pboard, c0)    
//CR 87        (rotors', c2) = joinRotors (rotors, c1)    
//CR 88        c3 = substFwd (refl, c2)    
//CR 89        c4 = backSignal(rotors, c3)    
//CR 90        c5 = substBwd (pboard, c4)    

function Tuple2 #(Vector #(n, Rotor), CharB) enigmaLoop (Plugboard          pboard,
							 Vector #(n, Rotor) rotors,
							 Reflector          refl,
							 CharB              c0);
   let c1 = substFwd (pboard, c0);
   match { .rotors_prime, .c2 } = joinRotors (rotors, c1);
   let c3 = substFwd (refl, c2);
   let c4 = backSignal (rotors, c3);
   let c5 = substBwd (pboard, c4);
   return tuple2 (rotors_prime, c5);
endfunction

//CR 91
//CR 92    // Construct a machine out of parts
//CR 93    mkEnigma : {n} (Plugboard, [n]Rotor, Reflector, [n]Char) -> Enigma n
//CR 94    mkEnigma (pboard, rs, refl, startingPositions) =
//CR 95        { plugboard = pboard
//CR 96        , rotors = [ r <<< (s - 'A')
//CR 97                   | r <- rs
//CR 98                   | s <- startingPositions
//CR 99                   ]
//CR 100       , reflector = refl    
//CR 101       }    

function Enigma #(n) mkEnigma (Plugboard           pboard,
			       Vector #(n, Rotor)  rs,
			       Reflector           refl,
			       String              startingPositions);
   List #(Char) sps = stringToCharList (startingPositions);
   function Rotor fn_rotor_j (Integer j) =
      rotateBy (rs [j],
		fromInteger (26 - charToInteger (sps [j]) + charToInteger ("A")));
   return Enigma {plugboard: pboard,
		  rotors:    genWith (fn_rotor_j),
		  reflector: refl};
endfunction

//CR 102
//CR 103    // Encryption/Decryption
//CR 104    enigma : {n, m} (fin n, fin m) => (Enigma n, String m) -> String m
//CR 105    enigma (m, pt) = tail [ c | (_, c) <- rcs ]
//CR 106      where rcs = [(m.rotors, '*')] #
//CR 107                  [ enigmaLoop (m.plugboard, r, m.reflector, c)
//CR 108                  | c <- pt
//CR 109                  | (r, _) <- rcs
//CR 110                  ]

function Vector #(textlen, CharB) enigma (Enigma #(n) m, Vector #(textlen, CharB) pt);
   Vector #(n, Rotor) rs = m.rotors;
   Vector #(textlen, CharB) ocs;
   for (Integer j = 0; j < valueOf (textlen); j = j + 1) begin
      match { .rs_prime, .oc } = enigmaLoop (m.plugboard, rs, m.reflector, pt [j]);
      rs  = rs_prime;
      ocs [j] = oc;
   end
   return ocs;
endfunction

//CR 111
//CR 112    // Decryption is the same as encryption:
//CR 113    // dEnigma : {n, m} (fin n, fin m) => (Enigma n, String m) -> String m
//CR 114    dEnigma = enigma

function Vector #(textlen, CharB) dEnigma (Enigma #(n) m, Vector #(textlen, CharB) pt)
   = enigma (m, pt);

//CR 115
//CR 116
//CR 117    // Build an example enigma machine:
//CR 118    plugboard : Plugboard
//CR 119    plugboard = "HBGDEFCAIJKOWNLPXRSVYTMQUZ"

Plugboard plugboard = stringToVCharB ("HBGDEFCAIJKOWNLPXRSVYTMQUZ");

//CR 120
//CR 121    rotor1, rotor2, rotor3 : Rotor
//CR 122    rotor1 = mkRotor ("RJICAWVQZODLUPYFEHXSMTKNGB", "IO")
//CR 123    rotor2 = mkRotor ("DWYOLETKNVQPHURZJMSFIGXCBA", "B")
//CR 124    rotor3 = mkRotor ("FGKMAJWUOVNRYIZETDPSHBLCQX", "CK")

Rotor rotor1 = mkRotor (stringToVCharB ("RJICAWVQZODLUPYFEHXSMTKNGB"), "IO");
Rotor rotor2 = mkRotor (stringToVCharB ("DWYOLETKNVQPHURZJMSFIGXCBA"), "B");
Rotor rotor3 = mkRotor (stringToVCharB ("FGKMAJWUOVNRYIZETDPSHBLCQX"), "CK");

//CR 125
//CR 126    reflector : Reflector
//CR 127    reflector = "FEIPBATSCYVUWZQDOXHGLKMRJN"

Reflector reflector = stringToVCharB ("FEIPBATSCYVUWZQDOXHGLKMRJN");

//CR 128
//CR 129    modelEnigma : Enigma 3
//CR 130    modelEnigma = mkEnigma (plugboard, [rotor1, rotor2, rotor3], reflector, "GCR")

Enigma #(3) modelEnigma = mkEnigma (plugboard,
				    vec (rotor1, rotor2, rotor3),
				    reflector,
				    "GCR");

//CR 131
//CR 132    /* Example run:
//CR 133
//CR 134       cryptol> :set ascii=on
//CR 135       cryptol> enigma (modelEnigma, "ENIGMAWASAREALLYCOOLMACHINE")
//CR 136       UPEKTBSDROBVTUJGNCEHHGBXGTF
//CR 137       cryptol> dEnigma (modelEnigma, "UPEKTBSDROBVTUJGNCEHHGBXGTF")
//CR 138       ENIGMAWASAREALLYCOOLMACHINE
//CR 139    */

// plaintext input
Vector #(27, CharB) pt_input    = stringToVCharB ("ENIGMAWASAREALLYCOOLMACHINE");
// expected ciphertext
Vector #(27, CharB) ct_expected = stringToVCharB ("UPEKTBSDROBVTUJGNCEHHGBXGTF");

// Encryption: do this in a testbench
//    action
//       let ct = enigma  (modelEnigma, pt_input);
//       displayVCharB ("Cipher text output:   ", ct, "\n");
//       if (ct != ct_expected)
//          displayVCharB ("Expected ciphertext:  ", ct_expected, "\n");
//    endaction

// Decryption: do this in a testbench
//    action
//       let pt_output = dEnigma (modelEnigma, ct_expected);
//       displayVCharB ("Plaintext output:     ", pt_output, "\n");
//       if (pt_output != pt_input)
//          displayVCharB ("Expected plaintext:   ", pt_input, "\n");
//    endaction

// ================================================================

endpackage
