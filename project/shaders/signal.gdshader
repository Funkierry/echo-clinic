shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float veil : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 0.12;
void fragment() {
    vec2 uv = SCREEN_UV;
    float slice = floor(uv.y * 55.0);
    float shift = sin(slice * 73.13 + floor(TIME * 18.0)) * step(0.75, fract(sin(slice * 17.3 + floor(TIME * 10.0)) * 43758.5));
    uv.x += shift * glitch * 0.035;
    vec3 color = texture(screen_texture, uv).rgb;
    color.r = mix(color.r, texture(screen_texture, uv + vec2(glitch * 0.006, 0)).r, glitch);
    color.b = mix(color.b, texture(screen_texture, uv - vec2(glitch * 0.006, 0)).b, glitch);
    float scanline = sin(FRAGCOORD.y * 3.141592) * 0.5 + 0.5;
    color *= 1.0 - scanline * strength;
    color *= 1.0 - veil;
    COLOR = vec4(color, 1.0);
}

