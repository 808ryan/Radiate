#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct GridUniforms {
    float2 viewportSize;
    uint columns;
    uint rows;
    uint sequence;
    uint profile;
    uint running;
    float contentInset;
    float borderWidth;
};

vertex VertexOut gridVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[] = {
        {-1.0, -1.0}, { 1.0, -1.0}, {-1.0,  1.0},
        {-1.0,  1.0}, { 1.0, -1.0}, { 1.0,  1.0}
    };
    constexpr float2 coordinates[] = {
        {0.0, 1.0}, {1.0, 1.0}, {0.0, 0.0},
        {0.0, 0.0}, {1.0, 1.0}, {1.0, 0.0}
    };

    VertexOut output;
    output.position = float4(positions[vertexID], 0.0, 1.0);
    output.uv = coordinates[vertexID];
    return output;
}

uint prbsWord(uint sequence, uint cellIndex) {
    uint value = sequence + cellIndex * 0x9E3779B9u;
    value ^= value >> 16;
    value *= 0x7FEB352Du;
    value ^= value >> 15;
    value *= 0x846CA68Bu;
    value ^= value >> 16;
    return value;
}

uint headerChecksum(uint profile, uint sequence) {
    uint folded = 0x5244u ^ (1u << 8) ^ profile ^ sequence ^ (sequence >> 16) ^ 0xA55Au;
    return folded & 0xFFFFu;
}

uint headerBit(uint bitIndex, constant GridUniforms &uniforms) {
    uint value;
    uint width;
    uint localIndex;

    if (bitIndex < 16u) {
        value = 0x5244u;
        width = 16u;
        localIndex = bitIndex;
    } else if (bitIndex < 24u) {
        value = 1u;
        width = 8u;
        localIndex = bitIndex - 16u;
    } else if (bitIndex < 32u) {
        value = uniforms.profile;
        width = 8u;
        localIndex = bitIndex - 24u;
    } else if (bitIndex < 64u) {
        value = uniforms.sequence;
        width = 32u;
        localIndex = bitIndex - 32u;
    } else {
        value = headerChecksum(uniforms.profile, uniforms.sequence);
        width = 16u;
        localIndex = bitIndex - 64u;
    }

    return (value >> (width - localIndex - 1u)) & 1u;
}

fragment float4 gridFragment(VertexOut input [[stage_in]],
                             constant GridUniforms &uniforms [[buffer(0)]]) {
    const float inset = uniforms.contentInset;
    const float border = uniforms.borderWidth;

    if (input.uv.x < inset - border || input.uv.x > 1.0 - inset + border ||
        input.uv.y < inset - border || input.uv.y > 1.0 - inset + border) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    if (input.uv.x < inset || input.uv.x > 1.0 - inset ||
        input.uv.y < inset || input.uv.y > 1.0 - inset) {
        return float4(1.0, 1.0, 1.0, 1.0);
    }

    if (uniforms.running == 0u) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    float2 gridUV = (input.uv - inset) / (1.0 - 2.0 * inset);
    uint column = min(uint(gridUV.x * float(uniforms.columns)), uniforms.columns - 1u);
    uint row = min(uint(gridUV.y * float(uniforms.rows)), uniforms.rows - 1u);

    uint bit = 0u;
    if (row < 6u) {
        uint headerIndex = column / 3u;
        bit = headerIndex < 80u ? headerBit(headerIndex, uniforms) : 0u;
    } else {
        uint payloadIndex = (row - 6u) * uniforms.columns + column;
        bit = prbsWord(uniforms.sequence, payloadIndex) & 1u;
    }

    float level = bit == 1u ? 1.0 : 0.0;
    return float4(level, level, level, 1.0);
}
