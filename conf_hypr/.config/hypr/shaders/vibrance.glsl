#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    float luma = dot(pixColor.rgb, vec3(0.3, 0.59, 0.11));
    // empurra as cores pra longe do cinza (saturação +20%)
    pixColor.rgb = mix(vec3(luma), pixColor.rgb, 1.2);
    fragColor = pixColor;
}
