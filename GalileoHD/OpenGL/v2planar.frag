precision highp float;

uniform sampler2D uvPlane;

varying highp vec2 coordinate;


// size used to extract Y
// halfsize - UV
uniform vec3 resultInvSize; // x = 1 / (width - 1), y = 1 / (height - 1), z = 1 / width, w = width * height
uniform vec3 resultSize; // x = width - 1, y = height - 1, z = width
uniform vec3 planeSize;

float getUV(float offset, vec3 size, vec3 invSize)
{
    // convert to local UV 
    //int channel = int(mod(offset, 4.0));
    //offset = floor(offset * 0.25); // divide 4
    float u = mod(offset, size.z) * invSize.x;
    float v = floor(offset * invSize.z) * invSize.y;
    
    return texture2D(uvPlane, vec2(u, v)).b;
}

void main()
{
	vec4 color = vec4(0.0, 0.0, 0.0, 0.0); 
	
	float yy = floor(coordinate.y * planeSize.y + 0.5);
    float xx = floor(coordinate.x * planeSize.x + 0.5);
    float offset = (yy * planeSize.z + xx) * 4.0;
	for(int i = 0; i < 4; i++)
	{
		color[i] = getUV(offset, resultSize, resultInvSize);
		offset += 1.0;
	}
	
	/*color[0] = getY(offset, resultSize, resultInvSize);
	color[1] = getY(offset + 1.0, resultSize, resultInvSize);
	color[2] = getY(offset + 2.0, resultSize, resultInvSize);
	color[3] = getY(offset + 3.0, resultSize, resultInvSize);//*/
	
	gl_FragColor = color;
}
