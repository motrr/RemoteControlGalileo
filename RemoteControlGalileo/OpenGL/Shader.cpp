#include "Shader.h"

#include <CoreFoundation/CoreFoundation.h>

// This function will locate the path to our application on OS X,
// unlike windows you can not rely on the curent working directory
// for locating your configuration files and resources.
std::string macBundlePath()
{
    char path[1024];
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    assert(mainBundle);
    
    CFURLRef mainBundleURL = CFBundleCopyBundleURL(mainBundle);
    assert(mainBundleURL);
    
    CFStringRef cfStringRef = CFURLCopyFileSystemPath(mainBundleURL, kCFURLPOSIXPathStyle);
    assert(cfStringRef);
    
    CFStringGetCString(cfStringRef, path, 1024, kCFStringEncodingASCII);
    
    CFRelease(mainBundleURL);
    CFRelease(cfStringRef);
    
    return std::string(path);
}

// Create and compile a shader from the provided source
GLint Shader::compileShader(GLuint *shader, GLenum type, const std::string &source, std::vector<std::string> *defines)
{
    if(source.empty())
        return GL_FALSE;

    GLint status;
    const GLchar *sources = 0;
    std::string src;

    if(defines)
    {
        std::vector<std::string>::iterator it = defines->begin();
        std::vector<std::string>::iterator iend = defines->end();

        for(; it != iend; ++it)
            src += "#define " + *it + "\n";

        src += source;
        sources = (GLchar *)&src[0];
    }
    else
        sources = (GLchar *)&source[0];

    *shader = glCreateShader(type);             // create shader
    glShaderSource(*shader, 1, &sources, NULL); // set source code in the shader
    glCompileShader(*shader);                   // compile shader

#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if(logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        printf("Shader compile log:\n%s", log);
        free(log);
    }
#endif

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if(status == GL_FALSE)
    {
        printf("Failed to compile shader:\n");
        printf("%s", sources);
    }

    return status;
}

// Link a program with all currently attached shaders
GLint Shader::linkProgram(GLuint prog)
{
    GLint status;
    glLinkProgram(prog);

#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if(logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        printf("Program link log:\n%s", log);
        free(log);
    }
#endif

    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if(status == GL_FALSE)
        printf("Failed to link program %d", prog);

    return status;
}

// delete shader resources
void Shader::destroyShaders(GLuint vertShader, GLuint fragShader, GLuint prog)
{
    if(vertShader)
    {
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    if(fragShader)
    {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    if(prog)
    {
        glDeleteProgram(prog);
        prog = 0;
    }
}

Shader::Shader(const std::string &vertexFile, const std::string &fragmentFile, bool fromBundle):
    mProgram(0)
{
    // load vertex shader
    std::string fileName = (fromBundle)	? macBundlePath() + "/" + vertexFile : vertexFile;
    FILE* file = fopen(fileName.c_str(), "rb");
    if(!file)
    {
        printf("Failed to load vertex shader");
        return;
    }

    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    rewind(file);

    mVertexSource.resize(size);
    fread(&mVertexSource[0], 1, size, file);
    fclose(file);

    // load fragment shader
    fileName = (fromBundle) ? macBundlePath() + "/" + fragmentFile : fragmentFile;
    file = fopen(fileName.c_str(), "rb");
    if(!file)
    {
        printf("Failed to load fragment shader");
        return;
    }

    fseek(file, 0, SEEK_END);
    size = ftell(file);
    rewind(file);

    mFragmentSource.resize(size);
    fread(&mFragmentSource[0], 1, size, file);
    fclose(file);
}

Shader::~Shader()
{
    // realease the shader program object
    if(mProgram)
    {
        glDeleteProgram(mProgram);
        mProgram = 0;
    }
}

bool Shader::compile(std::vector<std::string> *defines)
{
    GLuint vertShader = 0, fragShader = 0;

    // realease old shader program object if one exists
    if(mProgram)
    {
        glDeleteProgram(mProgram);
        mProgram = 0;
    }

    // create shader program
    mProgram = glCreateProgram();

    // create and compile vertex shader
    if(!compileShader(&vertShader, GL_VERTEX_SHADER, mVertexSource, defines))
    {
        destroyShaders(vertShader, fragShader, mProgram);
        return false;
    }

    // create and compile fragment shader
    if(!compileShader(&fragShader, GL_FRAGMENT_SHADER, mFragmentSource, defines))
    {
        destroyShaders(vertShader, fragShader, mProgram);
        return false;
    }

    // attach vertex shader to program
    glAttachShader(mProgram, vertShader);

    // attach fragment shader to program
    glAttachShader(mProgram, fragShader);

    // bind attribute locations
    // this needs to be done prior to linking
    glBindAttribLocation(mProgram, SA_POSITION, "position");
    glBindAttribLocation(mProgram, SA_NORMAL, "normal");
    glBindAttribLocation(mProgram, SA_COLOR, "color");
    glBindAttribLocation(mProgram, SA_TEXTURE0, "texCoord");
    glBindAttribLocation(mProgram, SA_TEXTURE0, "texCoord0");
    glBindAttribLocation(mProgram, SA_TEXTURE1, "texCoord1");
    glBindAttribLocation(mProgram, SA_TEXTURE2, "texCoord2");

    // link program
    if (!linkProgram(mProgram))
    {
        destroyShaders(vertShader, fragShader, mProgram);
        return false;
    }

    // release vertex and fragment shaders
    if (vertShader)
    {
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    if (fragShader)
    {
        glDeleteShader(fragShader);
        fragShader = 0;
    }

    return true;
}

// Validate a program (for i.e. inconsistent samplers)
bool Shader::validate()
{
    GLint logLength, status;

    glValidateProgram(mProgram);
    glGetProgramiv(mProgram, GL_INFO_LOG_LENGTH, &logLength);
    if(logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(mProgram, logLength, &logLength, log);
        printf("Program validate log:\n%s", log);
        free(log);
    }

    glGetProgramiv(mProgram, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE)
        printf("Failed to validate program %d", mProgram);

    return (status != 0);
}

void Shader::setFloat1(const std::string &name, float v1)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform1f(location, v1);
}

void Shader::setFloat2(const std::string &name, float v1, float v2)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform2f(location, v1, v2);
}

void Shader::setFloat3(const std::string &name, float v1, float v2, float v3)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform3f(location, v1, v2, v3);
}

void Shader::setFloat4(const std::string &name, float v1, float v2, float v3, float v4)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform4f(location, v1, v2, v3, v4);
}

void Shader::setFloatN(const std::string &name, const void *data, int count)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    if(count == 1)
        glUniform1fv(location, 1, (float*)data);
    else if(count == 2)
        glUniform2fv(location, 1, (float*)data);
    else if(count == 3)
        glUniform3fv(location, 1, (float*)data);
    else if(count == 4)
        glUniform4fv(location, 1, (float*)data);
}

void Shader::setInt1(const std::string &name, int v1)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform1i(location, v1);
}

void Shader::setInt2(const std::string &name, int v1, int v2)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform2i(location, v1, v2);
}

void Shader::setInt3(const std::string &name, int v1, int v2, int v3)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform3i(location, v1, v2, v3);
}

void Shader::setInt4(const std::string &name, int v1, int v2, int v3, int v4)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    glUniform4i(location, v1, v2, v3, v4);
}

void Shader::setIntN(const std::string &name, const void *data, int count)
{
    int location = glGetUniformLocation(mProgram, name.c_str());
    if(count == 1)
        glUniform1iv(location, 1, (int*)data);
    else if(count == 2)
        glUniform2iv(location, 1, (int*)data);
    else if(count == 3)
        glUniform3iv(location, 1, (int*)data);
    else if(count == 4)
        glUniform4iv(location, 1, (int*)data);
}

void Shader::bind()
{
    glUseProgram(mProgram);
}

void Shader::unbind()
{
    glUseProgram(0);
}