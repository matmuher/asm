#!/bin/bash

# Compile asm file
nasm -felf64 Asm_to_c.asm

# Compile cpp file
gcc -c asm_to_C.cpp

# Link asm and cpp file
gcc -no-pie -o asm_to_c.exe Asm_to_c.o asm_to_C.o