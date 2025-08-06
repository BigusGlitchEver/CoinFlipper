// shaders/title.glsl
// A shader that applies a wave and a rainbow color effect.

extern number time;
extern number wave_amplitude = 0.01;
extern number wave_frequency = 10.0;
extern number wave_speed = 2.0;
extern number color_frequency = 5.0;
extern number color_speed = 1.0;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Wave effect
    number offset = sin(texture_coords.x * wave_frequency + time * wave_speed) * wave_amplitude;
    vec2 wavy_coords = vec2(texture_coords.x, texture_coords.y + offset);
    vec4 tex_color = Texel(texture, wavy_coords);

    // Rainbow color effect
    vec3 rainbow;
    rainbow.r = sin(time * color_speed + texture_coords.x * color_frequency) * 0.5 + 0.5;
    rainbow.g = sin(time * color_speed + texture_coords.x * color_frequency + 2.0) * 0.5 + 0.5;
    rainbow.b = sin(time * color_speed + texture_coords.x * color_frequency + 4.0) * 0.5 + 0.5;

    // Combine the texture's alpha (the shape of the letter) with the rainbow color.
    // Multiply by the vertex color to allow for global color tints or fades.
    return vec4(rainbow, tex_color.a) * color;
}
