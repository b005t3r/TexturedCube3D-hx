// ported from: https://gist.github.com/noonat/847106

import hxd.fs.LoadedBitmap.LoadedBitmapData;
import hxd.fs.FileSystem;
import hxd.Timer;
import h3d.Buffer;
import h3d.Engine;
import h3d.Indexes;
import h3d.Vector;
import h3d.mat.BlendMode;
import h3d.mat.Data.Compare;
import h3d.mat.Data.Face;
import h3d.mat.Pass;
import h3d.shader.Buffers;
import h3d.shader.Manager;
import hxd.FloatBuffer;
import hxd.IndexBuffer;
import hxsl.RuntimeShader;
import hxsl.Shader;
import hxsl.ShaderList;
import hxsl.Types.Matrix;

class TexturedGeometryShader extends Shader {
    static var SRC = {
        // input values in each geometry vertex
        @input var input : {
            var pos:Vec3;           // position - 3 floats
            var color:Vec3;         // color - 3 floats
            var uv:Vec2;            // UVs - 2 floats
        };

        // output values expected by h3d.shader.Manager
        var output : {
            var position:Vec4;      // position - 4 floats
            var color:Vec4;         // color - 4 floats
        };

        // shader input parameters
        @param var modelMatrix:Mat4;        // model transofrmation matrix
        @param var projectionMatrix:Mat4;   // projection matrix
        @param var texture:Sampler2D;       // texture to read color data from

        // value passed from vertex shader to fragment shader
        var color:Vec3;             // color - 3 floats
        var uv:Vec2;                // UVs - 2 floats

        function vertex() {
            output.position = vec4(input.pos.xyz, 1) * modelMatrix * projectionMatrix;
            color           = input.color;
            uv              = input.uv;
        }

        function fragment() {
            //output.color = texture.get(uv) * vec4(color.xyz, 1);
            output.color = texture.get(uv) * min(vec4(color.xyz, 1) + vec4(0.75, 0.75, 0.75, 1), vec4(1, 1, 1, 1));
        }
    };
}

class Main {
    public static function main() { new Main(); }

    var engine:Engine;                      // Engine, it's Context3D equivalent in Stage3D APIs

    var shader:TexturedGeometryShader;      // uncompiled shader used for rendering
    var shaderList:ShaderList;              // shader list - used for compiling shaders
    var compiledShader:RuntimeShader;       // all compiled shaders
    var passSettings:Pass;                  // material, encapsulates things like culling, depth test, blending, etc.

    var shaderManager:Manager;              // shader manager
    var shaderBuffers:Buffers;              // shader buffers - used for passing params to compiled shaders

    var indices:IndexBuffer;                // indices to be passed to index buffer
    var vertices:FloatBuffer;               // vertices to be passed to vertec buffer

    var indexBuffer:Indexes;                // index buffer used for rendering
    var vertexBuffer:Buffer;                // vertex buffer used for rendering

    var fileSystem:FileSystem;              // file system used for loading resoruces
    var haxeLogoTexture:h3d.mat.Texture;    // texture to use when rendering

    var modelMatrix:Matrix;                 // madel transform matrix
    var projectionMatrix:Matrix;            // camera projection matrix

    var time:Float          = 0;
    var tweenTime:Float     = 0;
    var tweenPitch:Float    = 0;
    var tweenYaw:Float      = 0;
    var pitch:Float         = 0;
    var yaw:Float           = 0;

    // our model's colored geometry
    var cubeVertexes:Array<Float> = [
        // near face
        -1.0, -1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0,
        -1.0, 1.0, 1.0, 1.0, 0.0, 0.0,  0.0, 1.0,
        1.0, 1.0, 1.0, 1.0, 0.0, 0.0,   1.0, 1.0,
        1.0, -1.0, 1.0, 1.0, 0.0, 0.0,  1.0, 0.0,

        // left face
        -1.0, -1.0, -1.0, 0.0, 1.0, 0.0, 0.0, 0.0,
        -1.0, 1.0, -1.0, 0.0, 1.0, 0.0,  0.0, 1.0,
        -1.0, 1.0, 1.0, 0.0, 1.0, 0.0,   1.0, 1.0,
        -1.0, -1.0, 1.0, 0.0, 1.0, 0.0,  1.0, 0.0,

        // far face
        1.0, -1.0, -1.0, 0.0, 0.0, 1.0,  0.0, 0.0,
        1.0, 1.0, -1.0, 0.0, 0.0, 1.0,   0.0, 1.0,
        -1.0, 1.0, -1.0, 0.0, 0.0, 1.0,  1.0, 1.0,
        -1.0, -1.0, -1.0, 0.0, 0.0, 1.0, 1.0, 0.0,

        // right face
        1.0, -1.0, 1.0, 1.0, 1.0, 0.0,  0.0, 0.0,
        1.0, 1.0, 1.0, 1.0, 1.0, 0.0,   0.0, 1.0,
        1.0, 1.0, -1.0, 1.0, 1.0, 0.0,  1.0, 1.0,
        1.0, -1.0, -1.0, 1.0, 1.0, 0.0, 1.0, 0.0,

        // top face
        -1.0, 1.0, 1.0, 1.0, 0.0, 1.0,  0.0, 0.0,
        -1.0, 1.0, -1.0, 1.0, 0.0, 1.0, 0.0, 1.0,
        1.0, 1.0, -1.0, 1.0, 0.0, 1.0,  1.0, 1.0,
        1.0, 1.0, 1.0, 1.0, 0.0, 1.0,   1.0, 0.0,

        // bottom face
        -1.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, 0.0,
        -1.0, -1.0, 1.0, 0.0, 1.0, 1.0,  0.0, 1.0,
        1.0, -1.0, 1.0, 0.0, 1.0, 1.0,   1.0, 1.0,
        1.0, -1.0, -1.0, 0.0, 1.0, 1.0,  1.0, 0.0
    ];

    // model's indexes
    var cubeIndexes:Array<UInt> = [
        0, 1, 2,
        0, 2, 3,
        4, 5, 6,
        4, 6, 7,
        8, 9, 10,
        8, 10, 11,
        12, 13, 14,
        12, 14, 15,
        16, 17, 18,
        16, 18, 19,
        20, 21, 22,
        20, 22, 23
    ];

    public function new() {
        // copy model data to indices and vertices
        indices = new IndexBuffer();

        for(i in 0...cubeIndexes.length)
            indices.push(cubeIndexes[i]);

        vertices = new FloatBuffer();

        for(i in 0...cubeVertexes.length)
            vertices.push(cubeVertexes[i]);

        // initialize filesystem
        #if flash
        fileSystem = new hxd.fs.LocalFileSystem("assets");
        #elseif js
        fileSystem = hxd.fs.EmbedFileSystem.create("assets");
        #end

        // initialize engine
        engine = new Engine();
        engine.debug = true;
        engine.onReady = onEngineReady;
        engine.init();
    }

    private function onEngineReady() {
        // setup callback - used for resizing and next frame handling
        engine.onResized = onResize;
        hxd.System.setLoop(onNextFrame);

        // setup initial matrices
        modelMatrix         = new Matrix();
        projectionMatrix    = perspectiveProjection(60, engine.width / engine.height, 0.1, 2048);

        // create the shader and add it to shader list
        shader          = new TexturedGeometryShader();
        shaderList      = new ShaderList(shader);

        // setup culling, depth test and blend mode
        passSettings    = new Pass("standard pass");
        passSettings.culling = Face.None;
        passSettings.depth(true, Compare.LessEqual);
        passSettings.setBlendMode(BlendMode.Alpha);

        // create shader manager, compile the shader and create shader param buffer
        shaderManager   = new h3d.shader.Manager(["output.position", "output.color"]);
        compiledShader  = shaderManager.compileShaders(shaderList);
        shaderBuffers   = new Buffers(compiledShader);

        // setup things that need to only be done once - shader globals
        shaderManager.fillGlobals(shaderBuffers, compiledShader);
        engine.selectShader(compiledShader);
        engine.uploadShaderBuffers(shaderBuffers, BufferKind.Globals);

        // create index and vertex buffers - this uploads geometry data to the GPU
        indexBuffer     = Indexes.alloc(indices);
        vertexBuffer    = Buffer.ofFloats(vertices, 8, [BufferFlag.RawFormat]);

        // load texture
        var entry = fileSystem.get("haxe_logo.png");
        entry.loadBitmap(function(bitmap) {
            haxeLogoTexture = h3d.mat.Texture.fromBitmap(bitmap.toBitmap());
        });
    }

    private function onNextFrame() {
        if(haxeLogoTexture == null)
            return;

        // update timer
        Timer.update();

        // update model's tranformation matrix
        updateRotation();

        // setup matrixes used for rendering as shader's params
        shader.modelMatrix      = modelMatrix;
        shader.projectionMatrix = projectionMatrix;
        shader.texture          = haxeLogoTexture;

        // render thisng to the screen
        engine.begin();
        {
            // setup shader before rendering
            shaderManager.fillParams(shaderBuffers, compiledShader, shaderList);
            engine.selectShader(compiledShader);
            engine.selectMaterial(passSettings);
            engine.uploadShaderBuffers(shaderBuffers, BufferKind.Params);
            engine.uploadShaderBuffers(shaderBuffers, BufferKind.Textures);

            // clear the back buffer
            engine.clear(0xFF333333);

            // render to back buffer
            engine.renderIndexed(vertexBuffer, indexBuffer);
        }
        engine.end();
    }

    private function onResize() {
        // update the projection matrix - everything else is handled inside Engine
        projectionMatrix = perspectiveProjection(60, engine.width / engine.height, 0.1, 2048);
    }

    private function perspectiveProjection(fov:Float = 90, aspect:Float = 1, near:Float = 1, far:Float = 2048):Matrix {
        var y2:Float    = near * Math.tan(fov * Math.PI / 360);
        var y1:Float    = -y2;
        var x1:Float    = y1 * aspect;
        var x2:Float    = y2 * aspect;

        var a:Float     = 2 * near / (x2 - x1);
        var b:Float     = 2 * near / (y2 - y1);
        var c:Float     = (x2 + x1) / (x2 - x1);
        var d:Float     = (y2 + y1) / (y2 - y1);
        var q:Float     = -(far + near) / (far - near);
        var qn:Float    = -2 * (far * near) / (far - near);

        var m:Matrix = new Matrix();
        m.load([
            a, 0, 0, 0,
            0, b, 0, 0,
            c, d, q, -1,
            0, 0, qn, 0
        ]);

        return m;
    }

    private function updateRotation() {
        if(time == 0) {
            time       = Timer.deltaT;
            tweenTime  = time + 1;
        }
        else {
            time += Timer.deltaT;
        }

        while(tweenTime < time) {
            tweenTime += 1;
            pitch = (pitch + 60) % 360;
            yaw = (yaw + 40) % 360;
        }

        var factor:Float    = Math.max(0.0, Math.min(tweenTime - time, 1.0));
        factor              = 1.0 - Math.pow(factor, 4);

        tweenPitch = pitch + (60 * factor);
        tweenYaw   = yaw + (40 * factor);

        modelMatrix.identity();
        modelMatrix.rotateAxis(new h3d.Vector(1, 0, 0), Math.PI * tweenPitch / 180);
        modelMatrix.rotateAxis(new h3d.Vector(0, 1, 0), Math.PI * tweenYaw / 180);
        modelMatrix.translate(0, 0, -4);
    }
}
