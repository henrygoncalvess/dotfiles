#version 300 es
// "HDR" look — subtle: a touch more saturation than vibrance plus a light
// local-contrast pop. Not true HDR output (that needs a HDR display).
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

void main() {
    vec3 col = texture(tex, v_texcoord).rgb;

    // Gentle S-curve for local contrast ("pop"), blended in lightly.
    vec3 sc = col * col * (3.0 - 2.0 * col);
    col = mix(col, sc, 0.30);

    // Saturation lift — just a hair above vibrance.
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(luma), col, 1.22);

    // Slight exposure lift.
    col = clamp(col * 1.03, 0.0, 1.0);

    fragColor = vec4(col, 1.0);
}
