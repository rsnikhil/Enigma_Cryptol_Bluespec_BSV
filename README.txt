Copyright (c) 2015 Bluespec, Inc.  All Rights Reserved
Except: Cryptol code (in comments) copyright Galois, Inc.

This code has no practical use other than as a fun programming
exercise, for people interested in Haskell-like languages.

The "Enigma" was a German cryptography machine, heavily used during
World War 2.  It was the subject of intense code-breaking efforts by
Polish cryptographers initially, and later by Alan Turing and his
colleagues at Bletchley Park in England, which led to great advances
in Computer Science and Engineering.

Cryptol (www.cryptol.net) is a Haskell-based DSL for formal
specification, verification and development of existing and new
cryptographic algorithms.

Bluespec BSV (www.bluespec.com) is a Haskell-based DSL for designing
complex digital circuits, typically implemented in FPGAs and ASICs.

----------------------------------------------------------------
Doc/
  Enigma_Cryptol_Bluespec_BSV.pdf

    Slides for a talk given by Rishiyur Nikhil at the monthly Boston
    Haskell meeting on February 18, 2015.  Walks through the Cryptol
    and Bluespec BSV codes for modeling Enigma, and then runs various
    simulations to encrypt and decrypt messages, including a
    simulation in BSV-generated Verilog (Verilog is a standard
    hardware description language), and a viewing of hardware
    waveforms

  gtkwave_screenshot.tiff

    Screenshot of view of digital waveforms generated during a BSV simulation.

----------------------------------------------------------------
src_Cryptol/
  Cryptol.cry    (ignore: this is just the Cryptol standard prelude)
  Enigma.cry

    This is the 'Cryptol Enigma Simulator' code described in Chapter 4
    and Appendix C of the book (PDF available at: http://cryptol.net):

      Programming Cryptol (Cryptol: The Language of Cryptography)
      Levent Erkök, Dylan McNamee, Joe Kiniry, Iavor Diatchki and John Launchbury
      Galois, Inc., 2010-2014

  Enigma_annotated.cry

    Same as Enigma.cry, except for my slight reorganizations and additional comments.

To run the Cryptol code, download and install cryptol from cryptol.net,
run
  $ cryptol Enigma.cry
to get the interactive prompt,
and type in 'enigma' and 'dEnigma' commands (see examples in Enigma.cry)

----------------------------------------------------------------
src_BSV/
  Enigma.bsv

    Most of it is a direct, almost 1-for-1 transcription of Enigma.cry.
    In fact, we cut-and-paste the Cryptol code from the book into
    comments in this file, and intersperse it with the BSV
    transcriptions.

  HW_Enigma.bsv

    Wraps the code from Enigma.bsv into a hardware module with a
    hardware interface which accepts plaintext/ciphertext text
    sequentially and yields the corresponding ciphertext/plaintext
    sequentially (of course, remembering the state of the rotors in
    between each letter).

    This is NOT intended to demonstrate high-quality hardware (which
    requires refinement of this code), but to demonstrate that the
    Cryptol functional spec almost directly provides the first-cut in
    the hardware refinement.

  Tb.bsv

    A small testbench driver to demonstrate the code in action. Calls
    both the pure functions in Enigma.bsv, as well as the sequential
    I/O in HW_Enigma.bsv

----------------------------------------------------------------
Makefile

  For building and running the Bluespec BSV code.
  Requires Bluespec installation (contact www.bluespec.com).

  $ make compile link bsim
    To build and run a Bluesim simulation.
    Will create intermediate stuff (ignore) in directories ./build/ and ./build_vsim/
    Will create Bluesim executables bsim.exe and bsim.exe.so

  $ make rtl vlink vsim
    To generate Verilog, link a Verilog simulation and run it
    Generated verilog is in directory ./verilog/
    Requires a Verilog simulator such as iverilog, vcs, modelsim, ncsim, cvc, etc.
      Default is iverilog; you can chose a different Verilog simulator in the Makefile

    Will create intermediate stuff (ignore) in directories ./build/, ./build_v/
    Will create Verilog simulation executable in vsim.exe

transcript_bsim.txt
transcript_vsim.txt
  Transcripts of above 'make' commands, respectively

bsim_waves.vcd

  VCD waveform file generated during Bluesim simulation (viewable in
  any VCD waveform viewer, such as gtkwave).

----------------------------------------------------------------
