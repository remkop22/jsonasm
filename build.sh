#!/bin/bash
mkdir -p build
name=$(echo $1 | cut -f 1 -d '.')

nasm -g -f elf32 $1 -o ${name}.o
gcc -no-pie -ggdb -m32 ${name}.o -o ./build/${name}
rm ${name}.o

