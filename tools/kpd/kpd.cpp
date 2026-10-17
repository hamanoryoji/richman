// Minimal KPD container tool: [offset][le32 text_size][le32 packed_size][LZO]
#include "lzokay.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

static std::uint32_t le32(const std::uint8_t* p) {
    return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8) |
           (static_cast<std::uint32_t>(p[2]) << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}
static void put32(std::vector<std::uint8_t>& v, std::uint32_t x) {
    v.push_back(static_cast<std::uint8_t>(x & 0xff));
    v.push_back(static_cast<std::uint8_t>((x >> 8) & 0xff));
    v.push_back(static_cast<std::uint8_t>((x >> 16) & 0xff));
    v.push_back(static_cast<std::uint8_t>((x >> 24) & 0xff));
}

static std::vector<std::uint8_t> read_all(const fs::path& p) {
    std::ifstream in(p, std::ios::binary | std::ios::ate);
    if (!in) { std::fprintf(stderr, "open failed: %s\n", p.u8string().c_str()); std::exit(2); }
    auto n = static_cast<std::size_t>(in.tellg());
    std::vector<std::uint8_t> data(n);
    in.seekg(0);
    if (n && !in.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(n))) {
        std::fprintf(stderr, "read failed\n"); std::exit(2);
    }
    return data;
}
static void write_all(const fs::path& p, const std::vector<std::uint8_t>& d) {
    std::ofstream out(p, std::ios::binary);
    if (!out) { std::fprintf(stderr, "write failed: %s\n", p.u8string().c_str()); std::exit(2); }
    if (!d.empty()) out.write(reinterpret_cast<const char*>(d.data()), static_cast<std::streamsize>(d.size()));
}

int main(int argc, char** argv) {
    if (argc < 4) { std::fprintf(stderr, "usage: kpd dump|pack in out [offset]\n"); return 1; }
    const std::string mode = argv[1];
    const fs::path in = fs::u8path(argv[2]);
    const fs::path out = fs::u8path(argv[3]);
    auto data = read_all(in);

    if (mode == "dump") {
        if (data.size() < 9) { std::fprintf(stderr, "too small\n"); return 3; }
        const std::uint8_t off = data[0];
        std::vector<std::uint8_t> dec(data.size() - 1);
        for (std::size_t i = 0; i < dec.size(); ++i)
            dec[i] = static_cast<std::uint8_t>(data[i + 1] - off);
        const std::uint32_t text_size = le32(dec.data());
        const std::uint32_t packed_size = le32(dec.data() + 4);
        if (packed_size != dec.size() - 8) { std::fprintf(stderr, "size mismatch %u vs %zu\n", packed_size, dec.size() - 8); return 4; }
        std::vector<std::uint8_t> text(text_size);
        std::size_t actual = 0;
        auto r = lzokay::decompress(dec.data() + 8, packed_size, text.data(), text.size(), actual);
        if (r != lzokay::EResult::Success || actual != text.size()) {
            std::fprintf(stderr, "decompress failed r=%d actual=%zu\n", static_cast<int>(r), actual);
            return 5;
        }
        write_all(out, text);
        std::printf("dump %s -> %s (%u bytes)\n", argv[2], argv[3], text_size);
        return 0;
    }

    if (mode == "pack") {
        std::vector<std::uint8_t> packed(lzokay::compress_worst_size(data.size()));
        std::size_t packed_size = 0;
        auto r = lzokay::compress(data.data(), data.size(), packed.data(), packed.size(), packed_size);
        if (r != lzokay::EResult::Success) { std::fprintf(stderr, "compress failed\n"); return 6; }
        packed.resize(packed_size);
        const std::uint8_t off = argc > 4 ? static_cast<std::uint8_t>(std::stoul(argv[4])) : 0x30;
        std::vector<std::uint8_t> plain;
        put32(plain, static_cast<std::uint32_t>(data.size()));
        put32(plain, static_cast<std::uint32_t>(packed_size));
        plain.insert(plain.end(), packed.begin(), packed.end());
        std::vector<std::uint8_t> file;
        file.push_back(off);
        for (auto b : plain) file.push_back(static_cast<std::uint8_t>(b + off));
        write_all(out, file);
        std::printf("pack %s -> %s (raw %zu, packed %zu)\n", argv[2], argv[3], data.size(), packed_size);
        return 0;
    }

    std::fprintf(stderr, "unknown mode\n");
    return 1;
}
