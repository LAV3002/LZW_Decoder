# LZW_Decoder
X86 ASM

Interface: `size_t lzw_decode(const uint8_t *in, size_t in_size, uint8_t *restrict out, size_t out_size);`

Return value: number of decoded bytes or -1 in case of error

Calling convention: Cdecl
