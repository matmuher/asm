#!/bin/bash

# Compile assembly
nasm -felf64 c_to_Asm.asm

# Compile .cpp
gcc -c C_to_asm.cpp

# Link
gcc -no-pie -o c_to_asm.exe C_to_asm.o c_to_Asm.o