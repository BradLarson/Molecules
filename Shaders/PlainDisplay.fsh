precision mediump float;

varying highp vec2 textureCoordinate;

uniform sampler2D texture;
uniform sampler2D overlay;

void main()
{
    vec4 mainColor = texture2D(texture, textureCoordinate);
    vec4 overlayColor = texture2D(overlay, textureCoordinate);
    
    if (overlayColor.a < 1.0)
    {
       // gl_FragColor = mainColor;
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
    else
    {
        gl_FragColor = overlayColor;
//        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
//	gl_FragColor = vec4(textureCoordinate.s, textureCoordinate.t, 0.0, 1.0);
//	gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
