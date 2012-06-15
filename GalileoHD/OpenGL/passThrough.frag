

varying highp vec2 coordinate;
uniform sampler2D videoframe;

void main()
{
	gl_FragColor = texture2D(videoframe, vec2(coordinate.x, coordinate.y) );
}



