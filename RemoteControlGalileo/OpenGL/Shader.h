#ifndef Shader_H
#define Shader_H

#include <vector>
#include <string>

#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

enum ShaderAttribute
{
    SA_POSITION,
    SA_NORMAL,
    SA_COLOR,
    SA_TEXTURE0,
    SA_TEXTURE1,
    SA_TEXTURE2,
};

// todo: add ability to set custom attributes
class Shader
{
public:
    Shader(const std::string &vertexFile, const std::string &fragmentFile, bool fromBundle = true);
    ~Shader();
    
    bool compile(std::vector<std::string> *defines = 0);
    bool validate();
    void bind();
    void unbind();
    
    // parameter binding
    void setFloat1(const std::string &name, float v1);
    void setFloat2(const std::string &name, float v1, float v2);
    void setFloat3(const std::string &name, float v1, float v2, float v3);
    void setFloat4(const std::string &name, float v1, float v2, float v3, float v4);
    void setFloatN(const std::string &name, const void *data, int count);

    void setInt1(const std::string &name, int v1);
    void setInt2(const std::string &name, int v1, int v2);
    void setInt3(const std::string &name, int v1, int v2, int v3);
    void setInt4(const std::string &name, int v1, int v2, int v3, int v4);
    void setIntN(const std::string &name, const void *data, int count);
    
private:
    GLint compileShader(GLuint *shader, GLenum type, const std::string &source, std::vector<std::string> *defines);
    GLint linkProgram(GLuint prog);
    void destroyShaders(GLuint vertShader, GLuint fragShader, GLuint prog);
    
    std::string mVertexSource;
    std::string mFragmentSource;
    
    GLuint mProgram;
};

#endif
