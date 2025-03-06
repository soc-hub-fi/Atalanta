# On ISR wrappers

A current limitation with the Rust proc-macro based approach is that it's difficult to fully customize the interrupt calling convention in collaboration with the compiler.

The optimal ISR would look something like [inline.asm](inline.asm). Instead, we use something that looks more like [jump.asm](jump.asm), where the asm wrapper jumps into a Rust calling convention function.
