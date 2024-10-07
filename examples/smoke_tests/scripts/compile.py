#!/usr/bin/python3

import os
import sys
import argparse
import subprocess

# `BUILD_ROOT` is used to detect common files, and as the directory where `build/` for build
# artifacts is generated
BUILD_ROOT = os.path.normpath(f"{os.path.dirname(os.path.realpath(__file__))}/../")
OUT_DIR = f"{BUILD_ROOT}/build/"
CRT0_PATH = f"{BUILD_ROOT}/common/crt0.S"
LINK_SCRIPT_PATH = f"{BUILD_ROOT}/common/link.ld"

ARCH_FLAGS = f"-march=rv32emc_zicsr -mabi=ilp32e"
CFLAGS = f"-O0 -ffunction-sections -fdata-sections -g"
LDFLAGS = f"-T{LINK_SCRIPT_PATH} -nostartfiles"

def make_little(word):
    return word[2:4]+word[0:2]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('filename')
    parser.add_argument('--riscv-xlen', default="32")
    parser.add_argument('--clean', action="store_true")
    parser.add_argument('--verbose', '-v', action="store_true")
    args = parser.parse_args()

    if args.clean:
        os.system(f"rm -r {OUT_DIR}")

    fname, fext = os.path.splitext(args.filename)
    fstem = os.path.basename(fname)

    # Define target triple for used cross-compiler
    arch = "riscv"
    sub = args.riscv_xlen
    triple = f"{arch}{sub}-unknown-elf"
    xcomp_prefix = f"{triple}-"
    cc = f"{xcomp_prefix}gcc"

    def run_cmd(cmd):
        if args.verbose:
            print(cmd)
        subprocess.run([cmd], check = True, shell = True)

    def ccompile(in_file, opts = ""):
        fname, fext = os.path.splitext(in_file)
        fstem = os.path.basename(fname)
        compile_cmd = f"{cc} {ARCH_FLAGS} {CFLAGS} -c -g {in_file} -o {OUT_DIR}/{fstem}.o {opts}"
        run_cmd(compile_cmd)

    def link(in_file):
        fname, fext = os.path.splitext(in_file)
        fstem = os.path.basename(fname)
        link_cmd = f"{cc} {ARCH_FLAGS} {LDFLAGS} -o {OUT_DIR}/{fstem}.elf {OUT_DIR}/{fstem}.o {OUT_DIR}/crt0.o"
        run_cmd(link_cmd)

    def objdump(in_file):
        assert os.path.splitext(in_file)[-1] in [".elf", ""]
        objdump_cmd = f"{xcomp_prefix}objdump {in_file} -Ssd > {OUT_DIR}/{fstem}.dump"
        run_cmd(objdump_cmd)

    def dump_section(in_file, section, out_file):
        assert os.path.splitext(in_file)[-1] in [".elf", ""]
        objcopy_cmd = f"{xcomp_prefix}objcopy --dump-section {section}={out_file} {in_file}"
        run_cmd(objcopy_cmd)

    # Assert required directories exist before build
    os.system(f"mkdir -p {OUT_DIR} stims")

    # Compile & link
    if (fext == ".c"):
        try:
            ccompile(args.filename)
            ccompile(CRT0_PATH, "-DLANGUAGE_ASSEMBLY")
            link(args.filename)
        except subprocess.CalledProcessError:
            print("Compilation FAILED")
            sys.exit(1)

    elf_path = None
    if fext == ".c":
        # Use a previously compiled ELF file
        elf_path = f"{OUT_DIR}/{fstem}.elf"
    elif fext == ".elf" or fext == "":
        # Use the input file directly
        elf_path = f"{args.filename}"
    else:
        raise Exception("unknown input file type")

    # objdump
    try:
        objdump(elf_path)
    except subprocess.CalledProcessError:
        print("objdump FAILED")
        sys.exit(1)

    def section_to_stim(elf_path, section, out_stim):
        # Dump .section into a file in preparation of stim conversion
        section_file = f"{OUT_DIR}/{fstem}.elf{section}"
        dump_section(elf_path, section, section_file)

        if not os.path.isfile(section_file):
            print(f"section={section} not available, generating dummy {out_stim}")
            run_cmd(f"echo 00000000 > {out_stim}")
            return

        xxd_path = f"{section_file}.xxd"
        run_cmd(f"python3 {BUILD_ROOT}/scripts/xxd.py {section_file} > {xxd_path}")

        # Generate stim
        with open(xxd_path, "r") as xxdfile, open(out_stim, "a" ) as stimfile:
            dump_lines = []
            big_words = []
            little_words = []
            for line in xxdfile:
                dump_lines.append(line[9:])
            for line in dump_lines:
                chunks = line.split()[:-1]
                for chunk in chunks:
                    big_words.append(chunk)
            for word in big_words:
                little_words.append(make_little(word))

            i = 0
            while( i < len(little_words)):
                if len(little_words) - i < 2:
                    stim_line = f"0000{little_words[i]}\n"
                else:
                    stim_line = f"{little_words[i+1]}{little_words[i]}\n"
                i += 2
                stimfile.write(stim_line)


    # Place .text into a stim file for imem
    sections =[".text"] 
    imem_stim = f"stims/{fstem}_imem.hex"
    with open(imem_stim, 'w'):
        pass
    
    for section in sections:
        section_to_stim(elf_path, section, imem_stim)

    # Place .data and .sdata into a stim file for dmem
    sections =[".data",".sdata"]                  
    dmem_stim = f"stims/{fstem}_dmem.hex"
    with open(dmem_stim, 'w'):
        pass
    
    for section in sections:
        section_to_stim(elf_path, section, dmem_stim)

    print(f"Test compilation complete, output hex in {imem_stim}, {dmem_stim}")
    if (fext == ".c"):
        print(f"ELF generated in {OUT_DIR}/{fstem}.elf")

if __name__ == "__main__":
    main()
