// assets/shaders/mask.glsl
// This shader applies an alpha mask to a texture.
// It multiplies the alpha of the source texture by the alpha of the mask texture.

extern Image maskTexture;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Get the original color from the image we want to draw
    vec4 original_color = Texel(texture, texture_coords);
    
    // Get the alpha value from the mask texture
    float mask_alpha = Texel(maskTexture, texture_coords).a;
    
    // Multiply the original color's alpha by the mask's alpha
    original_color.a = original_color.a * mask_alpha;
    
    // Return the final color, multiplied by the global color for tinting
    return original_color * color;
}
