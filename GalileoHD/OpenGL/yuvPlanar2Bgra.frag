
precision highp int;
precision highp float;

varying highp vec2 coordinate;
uniform sampler2D videoframe;

void main()
{
    
    
    float w,h;
    int w_i, h_i;
    
    w = 640.0;
    h = 960.0;
    w_i = int(w);
    h_i = int(h);
    
    float y, u, v, a;
    
    int byte_idx;
    int pixel_idx;
    //
    int dst_x, dst_y;
    float dst_x_n, dst_y_n;
    //
    int src_x, src_y, src_ch;
    float src_x_n, src_y_n;
    
    // Get normalised destination coords
    dst_x_n = coordinate.x;
    dst_y_n = coordinate.y;
    
    // Map normalised destination coords to pixel coords
    dst_x = int( floor(dst_x_n * w) );
    dst_y = int( floor(dst_y_n * h) );
    
    // Map destination coords to pixel index
    byte_idx = (dst_y*w_i) + dst_x;
    src_ch = 3 - int( mod(float(byte_idx+1), 4.0) );
    pixel_idx = int( floor( (float(byte_idx) / 4.0) ));
    
    // Map pixel index to source coords
    src_x = int( mod(float(pixel_idx), w) );
    src_y = (pixel_idx - src_x) / w_i;

    // Normalise source coords
    src_x_n = float(src_x) / w;
    src_y_n = float(src_y) / h;
    
    if (src_x_n < 0.5) {
        y = texture2D( videoframe, vec2(src_x_n,src_y_n) )[src_ch];
    }
    else {
        y= 0.0;
    }
    
    
    u = 0.0;
    v = 0.0;
    a = 1.0;
    
    gl_FragColor = vec4(y, u, v, a);
    
}

