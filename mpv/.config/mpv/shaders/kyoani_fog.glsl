// interpolates luma from 16-235 to 0-235

//!HOOK LUMA
//!BIND HOOKED
//!DESC Anti Kyoani Fog

#define const_1 ( 16.0 / 235.0)
#define const_2 (235.0 / 219.0)

vec4 hook() {
    return (LUMA_tex(LUMA_pos) - const_1) * const_2;
}
