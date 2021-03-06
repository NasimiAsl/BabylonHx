package com.babylonhx.sprites;

import com.babylonhx.materials.Effect;
import com.babylonhx.mesh.WebGLBuffer;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.mesh.Buffer;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.tools.Tools;
import com.babylonhx.math.Vector3;
import com.babylonhx.math.Matrix;
import com.babylonhx.collisions.PickingInfo;
import com.babylonhx.culling.Ray;
import com.babylonhx.cameras.Camera;
import com.babylonhx.tools.Observable;
import com.babylonhx.tools.Observer;
import com.babylonhx.tools.EventState;

import com.babylonhx.utils.typedarray.Float32Array;


/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.SpriteManager') class SpriteManager implements ISmartArrayCompatible {
	
	public var name:String;
	public var sprites:Array<Sprite> = [];
	public var renderingGroupId:Int = 0;
	public var layerMask:Int = 0x0FFFFFFF;
	public var fogEnabled:Bool = true;
	public var isPickable = false;
	public var cellWidth:Int;
	public var cellHeight:Int;
	
	public var __smartArrayFlags:Array<Int> = [];
	
	/**
	* An event triggered when the manager is disposed.
	* @type {BABYLON.Observable}
	*/
	public var onDisposeObservable = new Observable<SpriteManager>();

	private var _onDisposeObserver:Observer<SpriteManager>;
	public var onDispose(never, set):SpriteManager->Null<EventState>->Void;
	private function set_onDispose(callback:SpriteManager->Null<EventState>->Void):SpriteManager->Null<EventState>->Void {
		if (this._onDisposeObserver != null) {
			this.onDisposeObservable.remove(this._onDisposeObserver);
		}
		this._onDisposeObserver = this.onDisposeObservable.add(callback);
		
		return callback;
	}

	private var _capacity:Int;
	private var _spriteTexture:Texture;
	private var _epsilon:Float;

	private var _scene:Scene;

	private var _vertexData:Array<Float>;
	private var _buffer:Buffer;
	private var _vertexBuffers:Map<String, VertexBuffer> = new Map();
	private var _indexBuffer:WebGLBuffer;
	private var _effectBase:Effect;
	private var _effectFog:Effect;
	
	public var texture(get, set):Texture;
	

	public function new(name:String, imgUrl:String, capacity:Int, cellSize:Dynamic, scene:Scene, epsilon:Float = 0.01, ?samplingMode:Int = Texture.TRILINEAR_SAMPLINGMODE) {
		this.name = name;
		
		this._capacity = capacity;
		this._spriteTexture = new Texture(imgUrl, scene, true, false, samplingMode);
		this._spriteTexture.wrapU = Texture.CLAMP_ADDRESSMODE;
		this._spriteTexture.wrapV = Texture.CLAMP_ADDRESSMODE;
		this._epsilon = epsilon;
		
		if (cellSize != null) {
			if (cellSize.width != null && cellSize.height != null) {
				this.cellWidth = cellSize.width;
				this.cellHeight = cellSize.height;
			}
			else {
				this.cellWidth = cellSize;
				this.cellHeight = cellSize;
			}
		}
		else {
			return;
		}
		
		this._scene = scene;
		this._scene.spriteManagers.push(this);
		
		var indices:Array<Int> = [];
		var index:Int = 0;
		for (count in 0...capacity) {
			indices.push(index);
			indices.push(index + 1);
			indices.push(index + 2);
			indices.push(index);
			indices.push(index + 2);
			indices.push(index + 3);
			index += 4;
		}
		
		this._indexBuffer = scene.getEngine().createIndexBuffer(indices);
		
		// VBO
            // 16 floats per sprite (x, y, z, angle, sizeX, sizeY, offsetX, offsetY, invertU, invertV, cellIndexX, cellIndexY, color r, color g, color b, color a)
		this._vertexData = [];// new Float32Array(capacity * 16 * 4);
		for (i in 0...Std.int(capacity * 16 * 4)) {
			this._vertexData[i] = 0;
		}
		this._buffer = new Buffer(scene.getEngine(), this._vertexData, true, 16);
		
		var positions = this._buffer.createVertexBuffer(VertexBuffer.PositionKind, 0, 4);
		var options = this._buffer.createVertexBuffer("options", 4, 4);
		var cellInfo = this._buffer.createVertexBuffer("cellInfo", 8, 4);
		var colors = this._buffer.createVertexBuffer(VertexBuffer.ColorKind, 12, 4);
		
		this._vertexBuffers[VertexBuffer.PositionKind] = positions;
		this._vertexBuffers["options"] = options;
		this._vertexBuffers["cellInfo"] = cellInfo;
		this._vertexBuffers[VertexBuffer.ColorKind] = colors;
		
		// Effects
		this._effectBase = this._scene.getEngine().createEffect("sprites",
			[VertexBuffer.PositionKind, "options", "cellInfo", VertexBuffer.ColorKind],
			["view", "projection", "textureInfos", "alphaTest"],
			["diffuseSampler"], "");
			
		this._effectFog = this._scene.getEngine().createEffect("sprites",
			[VertexBuffer.PositionKind, "options", "cellInfo", VertexBuffer.ColorKind],
			["view", "projection", "textureInfos", "alphaTest", "vFogInfos", "vFogColor"],
			["diffuseSampler"], "#define FOG");
	}
	
	private function get_texture():Texture {
		return this._spriteTexture;
	}
	private function set_texture(value:Texture):Texture {
		return this._spriteTexture = value;
	}

	private function _appendSpriteVertex(index:Int, sprite:Sprite, offsetX:Float, offsetY:Float, rowSize:Int) {
		var arrayOffset = index * 16;
		
		if (offsetX == 0) {
			offsetX = this._epsilon;
		}
		else if (offsetX == 1) {
			offsetX = 1 - this._epsilon;
		}
			
		if (offsetY == 0) {
			offsetY = this._epsilon;
		}
		else if (offsetY == 1) {
			offsetY = 1 - this._epsilon;
		}
			
		this._vertexData[arrayOffset] = sprite.position.x;
		this._vertexData[arrayOffset + 1] = sprite.position.y;
		this._vertexData[arrayOffset + 2] = sprite.position.z;
		this._vertexData[arrayOffset + 3] = sprite.angle;
		this._vertexData[arrayOffset + 4] = sprite.width;
		this._vertexData[arrayOffset + 5] = sprite.height;
		this._vertexData[arrayOffset + 6] = offsetX;
		this._vertexData[arrayOffset + 7] = offsetY;
		this._vertexData[arrayOffset + 8] = sprite.invertU ? 1 : 0;
		this._vertexData[arrayOffset + 9] = sprite.invertV ? 1 : 0;
		var offset = Std.int(sprite.cellIndex / rowSize);
		this._vertexData[arrayOffset + 10] = sprite.cellIndex - offset * rowSize;
		this._vertexData[arrayOffset + 11] = offset;
		// Color
		this._vertexData[arrayOffset + 12] = sprite.color.r;
		this._vertexData[arrayOffset + 13] = sprite.color.g;
		this._vertexData[arrayOffset + 14] = sprite.color.b;
		this._vertexData[arrayOffset + 15] = sprite.color.a;
	}
	
	public function intersects(ray:Ray, camera:Camera, ?predicate:Sprite->Bool, fastCheck:Bool = false):PickingInfo {
		var count:Int = Std.int(Math.min(this._capacity, this.sprites.length));
		var min:Vector3 = Vector3.Zero();
		var max:Vector3 = Vector3.Zero();
		var distance = Math.POSITIVE_INFINITY;
		var currentSprite:Sprite = null;
		var cameraSpacePosition:Vector3 = Vector3.Zero();
		var cameraView:Matrix = camera.getViewMatrix();
		
		for (index in 0...count) {
			var sprite = this.sprites[index];
			if (sprite == null) {
				continue;
			}
			
			if (predicate != null) {
				if (!predicate(sprite)) {
					continue;
				}
			} 
			else if (!sprite.isPickable) {
				continue;
			}
			
			Vector3.TransformCoordinatesToRef(sprite.position, cameraView, cameraSpacePosition);
			
			min.copyFromFloats(cameraSpacePosition.x - sprite.width / 2, cameraSpacePosition.y - sprite.height / 2, cameraSpacePosition.z);
			max.copyFromFloats(cameraSpacePosition.x + sprite.width / 2, cameraSpacePosition.y + sprite.height / 2, cameraSpacePosition.z);
			
			if (ray.intersectsBoxMinMax(min, max)) {
				var currentDistance = Vector3.Distance(cameraSpacePosition, ray.origin);
				
				if (distance > currentDistance) {
					distance = currentDistance;
					currentSprite = sprite;
					
					if (fastCheck) {
						break;
					}
				}
			}
		}
		
		if (currentSprite != null) {
			var result = new PickingInfo();
			
			result.hit = true;
			result.pickedSprite = currentSprite;
			result.distance = distance;
			
			return result;
		}
		
		return null;
	} 

	public function render() {
		// Check
		if (!this._effectBase.isReady() || !this._effectFog.isReady() || this._spriteTexture == null || !this._spriteTexture.isReady()) {
			return;
		}
		
		var engine = this._scene.getEngine();
		var baseSize = this._spriteTexture.getBaseSize();
		
		// Sprites
		var deltaTime = engine.getDeltaTime();
		var max:Int = cast Math.min(this._capacity, this.sprites.length);
		var rowSize:Int = cast baseSize.width / this.cellWidth;
		
		var offset:Int = 0;
		for (index in 0...max) {
			var sprite = this.sprites[index];
			if (sprite == null) {
				continue;
			}
			
			sprite._animate(deltaTime);
			
			this._appendSpriteVertex(offset++, sprite, 0, 0, rowSize);
			this._appendSpriteVertex(offset++, sprite, 1, 0, rowSize);
			this._appendSpriteVertex(offset++, sprite, 1, 1, rowSize);
			this._appendSpriteVertex(offset++, sprite, 0, 1, rowSize);
		}
		
		this._buffer.update(this._vertexData);
		
		// Render
		var effect = this._effectBase;
		
		if (this._scene.fogEnabled && this._scene.fogMode != Scene.FOGMODE_NONE && this.fogEnabled) {
			effect = this._effectFog;
		}
		
		engine.enableEffect(effect);
		
		var viewMatrix = this._scene.getViewMatrix();
		effect.setTexture("diffuseSampler", this._spriteTexture);
		effect.setMatrix("view", viewMatrix);
		effect.setMatrix("projection", this._scene.getProjectionMatrix());
		
		effect.setFloat2("textureInfos", this.cellWidth / baseSize.width, this.cellHeight / baseSize.height);
		
		// Fog
		if (this._scene.fogEnabled && this._scene.fogMode != Scene.FOGMODE_NONE && this.fogEnabled) {
			effect.setFloat4("vFogInfos", this._scene.fogMode, this._scene.fogStart, this._scene.fogEnd, this._scene.fogDensity);
			effect.setColor3("vFogColor", this._scene.fogColor);
		}
		
		// VBOs
		engine.bindBuffers(this._vertexBuffers, this._indexBuffer, effect);
		
		// Draw order
		engine.setDepthFunctionToLessOrEqual();
		effect.setBool("alphaTest", true);
		engine.setColorWrite(false);
		engine.draw(true, 0, max * 6);
		engine.setColorWrite(true);
		effect.setBool("alphaTest", false);
		
		engine.setAlphaMode(Engine.ALPHA_COMBINE);
		engine.draw(true, 0, max * 6);
		engine.setAlphaMode(Engine.ALPHA_DISABLE);
	}

	public function dispose() {
		if (this._buffer != null) {
			this._buffer.dispose();
			this._buffer = null;
		}
		
		if (this._indexBuffer != null) {
			this._scene.getEngine()._releaseBuffer(this._indexBuffer);
			this._indexBuffer = null;
		}
		
		if (this._spriteTexture != null) {
			this._spriteTexture.dispose();
			this._spriteTexture = null;
		}
		
		// Remove from scene
		this._scene.spriteManagers.remove(this);
		
		this.onDisposeObservable.notifyObservers(this);
        this.onDisposeObservable.clear();
	}
	
}
