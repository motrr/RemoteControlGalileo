#include "GLConstants.h"

namespace GL
{

GLfloat unitSquareVertices[8] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f
};

GLfloat originCentredSquareVertices[8] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f, 1.0f,
    1.0f, 1.0f
};

GLfloat yPlaneUVs[8] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 0.3f,
    1.0f, 0.3f
};

GLfloat yPlaneVertices[8] = {
    -1.0f, -1.0f,
     1.0f, -1.0f,
    -1.0f, -0.4f,
     1.0f, -0.4f
};

GLfloat uvPlaneUVs[8] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 0.1f,
    1.0f, 0.1f
};

GLfloat uPlaneVertices[8] = {
    -1.0f, -0.4f,
     1.0f, -0.4f,
    -1.0f, -0.2f,
     1.0f, -0.2f
};

GLfloat vPlaneVertices[8] = {
    -1.0f, -0.2f,
     1.0f, -0.2f,
    -1.0f,  0.0f,
     1.0f,  0.0f
};

}