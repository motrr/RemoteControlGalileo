/*
     File: ShaderUtilities.h
 Abstract: Shader compiler and linker unilities
  Version: 1.2
 
LGT
 
 */

#ifndef LGT_ShaderUtilities_h
#define LGT_ShaderUtilities_h
    
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

GLint glueCompileShader(GLenum target, GLsizei count, const GLchar **sources, GLuint *shader);
GLint glueLinkProgram(GLuint program);
GLint glueValidateProgram(GLuint program);
GLint glueGetUniformLocation(GLuint program, const GLchar *name);

GLint glueCreateProgram(const GLchar *vertSource, const GLchar *fragSource,
                        GLsizei attribNameCt, const GLchar **attribNames, 
                        const GLint *attribLocations,
                        GLsizei uniformNameCt, const GLchar **uniformNames,
                        GLint *uniformLocations,
                        GLuint *program);

#endif
