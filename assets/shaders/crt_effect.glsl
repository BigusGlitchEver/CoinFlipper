
extern vec2 screenSize;
extern number time;

const float PI = 3.14159265359;

// Configurations
const float scanline_intensity = 0.2;
const float scanline_speed = 1.0;

const float curve_intensity = 0.1;

const float vignette_intensity = 1.2;
const float vignette_smoothness = 0.6;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;
    vec2 screen_uv = screen_coords / screenSize.xy;

    // Screen Curvature with Auto-Scaling
    vec2 centered_uv = uv - 0.5;
    float r2 = dot(centered_uv, centered_uv);
    vec2 distorted_uv = centered_uv / (1.0 - curve_intensity * r2);

    // Calculate scaling factor to remove black borders
    float corner_r2 = dot(vec2(0.5, 0.5), vec2(0.5, 0.5));
    float scale = 1.0 / (1.0 - curve_intensity * corner_r2);
    uv = (distorted_uv / scale) + 0.5;

    // Scanlines
    float scanline = sin((uv.y + time * scanline_speed) * screenSize.y * 0.5 * PI) * scanline_intensity;

    // Vignette
    float vignette = smoothstep(vignette_intensity, vignette_smoothness, length(screen_uv - 0.5));

    vec4 pixel = Texel(texture, uv);

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        pixel = vec4(0.0, 0.0, 0.0, 1.0);
    }

    pixel.rgb -= scanline;
    pixel.rgb *= vignette;

    return pixel;
}
