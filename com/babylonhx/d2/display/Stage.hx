package com.babylonhx.d2.display;

import com.babylonhx.d2.events.KeyboardEvent;
import com.babylonhx.d2.events.TouchEvent;
import com.babylonhx.d2.events.Event;
import com.babylonhx.d2.events.EventDispatcher;
import com.babylonhx.d2.events.MouseEvent;
import com.babylonhx.d2.geom.Point;

import com.babylonhx.utils.GL;
import com.babylonhx.utils.GL.GLBuffer;
import com.babylonhx.utils.GL.GLFramebuffer;
import com.babylonhx.utils.GL.GLProgram;
import com.babylonhx.utils.GL.GLShader;
import com.babylonhx.utils.GL.GLTexture;
import com.babylonhx.utils.GL.GLUniformLocation;
import com.babylonhx.utils.typedarray.Float32Array;
import com.babylonhx.utils.typedarray.UInt16Array;


/**
 * ...
 * @author Krtolica Vujadin
 */
class Stage extends DisplayObjectContainer {
	
	static private var _okKeys:Array<Int> = [	// keyCodes, which are not prevented by IvanK
		112, 113, 114, 115,   116, 117, 118, 119,   120, 121, 122, 123,	// F1 - F12
		13,	// Enter
		16,	// Shift
		//17,	// Ctrl
		18,	// Alt
		27	// Esc
	];
	
	public var _mouseX:Int = 0;
	public var _mouseY:Int = 0;
	
	static private var _curBF:GLBuffer = null;
	static private var _curEBF:GLBuffer = null;
	
	static private var _curVC:GLBuffer = null;
	static private var _curTC:GLBuffer = null;
	static private var _curUT:Int = 0;
	static private var _curTEX:GLTexture = null;
	
	static private var _curBMD:BlendMode = BlendMode.NORMAL;
	
	static public var _main:Stage;
	
	public var stageWidth:Int;
	public var stageHeight:Int;
	
	private var _dpr:Float;
	
	private var _svec4_0:Float32Array;
	private var _svec4_1:Float32Array;
	
	private var _pmat:Float32Array;
	private var _umat:Float32Array;
	private var _smat:Float32Array;
	
	private var _knM:Bool;
	public var _mstack:MStack;
	public var _cmstack:CMStack;
	public var _sprg:WebGLProgram;
	
	public var _unitIBuffer:GLBuffer;
	
	private var _mcEvs:Array<MouseEvent>;
	private var _mdEvs:Array<MouseEvent>;
	private var _muEvs:Array<MouseEvent>;
	
	private var _smd:Array<Bool>;
	private var _smu:Array<Bool>;
	
	private var _smm:Bool;
	private var _srs:Bool;
	
	public var focus:DisplayObject;
	public var _focii:Array<DisplayObject>;
	public var _mousefocus:DisplayObject;
	
	private var _touches:Map<String, Dynamic> = new Map();
	

	public function new(width:Int, height:Int, dpr:Float = 1) {
		super();
		
		this._dpr = dpr;
		
		this.stage = this;
		
		this.stageWidth = width;
		this.stageHeight = height;
		
		this.focus				= null;			// keyboard focus, never Stage
		this._focii 			= [null, null, null];
		this._mousefocus 		= null;			// mouse focus of last mouse move, used to detect MOUSE_OVER / OUT, never Stage
		
		this._knM = false;					// know mouse
		this._mstack = new MStack();		// transform matrix stack
		this._cmstack = new CMStack();		// color matrix stack
		this._sprg = null;
		
		this._svec4_0	= Point._v4_Create();
		this._svec4_1	= Point._v4_Create();
		
		this._pmat = Point._m4_Create(new Float32Array([
			 1, 0, 0, 0,
			 0, 1, 0, 0,
			 0, 0, 1, 1,
			 0, 0, 0, 1
		]));	// project matrix
		
		this._umat = Point._m4_Create(new Float32Array([
			 2, 0, 0, 0,
			 0,-2, 0, 0,
			 0, 0, 2, 0,
			-1, 1, 0, 1
		]));	// unit matrix
		
		this._smat = Point._m4_Create(new Float32Array([
			 0, 0, 0, 0,
			 0, 0, 0, 0,
			 0, 0, 0.001, 0,
			 0, 0, 0, 1
		]));	// scale matrix
		
		this._mcEvs = [	new MouseEvent(MouseEvent.CLICK			,true), 
						new MouseEvent(MouseEvent.MIDDLE_CLICK	,true), 
						new MouseEvent(MouseEvent.RIGHT_CLICK	,true) ];
						
		this._mdEvs = [ new MouseEvent(MouseEvent.MOUSE_DOWN		,true),
						new MouseEvent(MouseEvent.MIDDLE_MOUSE_DOWN	,true),
						new MouseEvent(MouseEvent.RIGHT_MOUSE_DOWN	,true) ];
						
		this._muEvs = [ new MouseEvent(MouseEvent.MOUSE_UP			,true),
						new MouseEvent(MouseEvent.MIDDLE_MOUSE_UP	,true),
						new MouseEvent(MouseEvent.RIGHT_MOUSE_UP	,true) ];
		
		this._smd   = [false, false, false];	// stage mouse down, for each mouse button
		this._smu   = [false, false, false];	// stage mouse up, for each mouse button
		
		this._smm  = false;	// stage mouse move
		this._srs  = false;	// stage resized
		
		Stage._main = this;
		
        this._initShaders();
        this._initBuffers();
		
        //GL.clearColor(0, 0, 0, 0);
		
		GL.enable(GL.BLEND);
		GL.blendEquation(GL.FUNC_ADD);		
		GL.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA);
		
		GL.enable(GL.DEPTH_TEST);
		GL.depthFunc(GL.LEQUAL);
		
		this._resize();
		this._srs = true;
	}
	
	inline public function _getOrigin(org:Float32Array) {
		org[0] = this.stageWidth / 2;  
		org[1] = this.stageHeight / 2;  
		org[2] = -500;  
		org[3] = 1;
	}
	
	inline public static function _setBF(bf:GLBuffer) {
		if (Stage._curBF != bf) {
			GL.bindBuffer(GL.ARRAY_BUFFER, bf);
			Stage._curBF = bf;
		}
	}
	
	inline public static function _setEBF(ebf:GLBuffer) {
		if(Stage._curEBF != ebf) {
			GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebf);
			Stage._curEBF = ebf;
		}
	}
	
	inline public static function _setVC(vc:GLBuffer) {
		if (Stage._curVC != vc) {
			GL.bindBuffer(GL.ARRAY_BUFFER, vc);
			GL.vertexAttribPointer(Stage._main._sprg.vpa, 3, GL.FLOAT, false, 0, 0);
			Stage._curVC = Stage._curBF = vc;
		}
	}
	
	inline public static function _setTC(tc:GLBuffer) {
		if (Stage._curTC != tc) {
			GL.bindBuffer(GL.ARRAY_BUFFER, tc);
			GL.vertexAttribPointer(Stage._main._sprg.tca, 2, GL.FLOAT, false, 0, 0);
			Stage._curTC = Stage._curBF = tc;
		}
	}
	
	inline public static function _setUT(ut:Int) {
		if (Stage._curUT != ut) {
			GL.uniform1i(Stage._main._sprg.useTex, ut);
			Stage._curUT = ut;
		}
	}
	
	inline public static function _setTEX(tex:GLTexture) {
		if (Stage._curTEX != tex) {
			GL.bindTexture(GL.TEXTURE_2D, tex);
			Stage._curTEX = tex;
		}
	}
	
	public static function _setBMD(bmd:BlendMode) {
		if(Stage._curBMD != bmd) {
			if (bmd == BlendMode.NORMAL) {
				GL.blendEquation(GL.FUNC_ADD);
				GL.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA);
			}
			else if	(bmd == BlendMode.MULTIPLY) {
				GL.blendEquation(GL.FUNC_ADD);
				GL.blendFunc(GL.DST_COLOR, GL.ONE_MINUS_SRC_ALPHA);
			}
			else if	(bmd == BlendMode.ADD)	  {
				GL.blendEquation(GL.FUNC_ADD);
				GL.blendFunc(GL.ONE, GL.ONE);
			}
			else if (bmd == BlendMode.SUBTRACT) { 
				GL.blendEquationSeparate(GL.FUNC_REVERSE_SUBTRACT, GL.FUNC_ADD);
				GL.blendFunc(GL.ONE, GL.ONE); 
			}
			else if (bmd == BlendMode.SCREEN) { 
				GL.blendEquation(GL.FUNC_ADD);
				GL.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_COLOR);
			}
			else if (bmd == BlendMode.ERASE) { 
				GL.blendEquation(GL.FUNC_ADD);
				GL.blendFunc(GL.ZERO, GL.ONE_MINUS_SRC_ALPHA);
			}
			else if (bmd == BlendMode.ALPHA) {
				GL.blendEquation(GL.FUNC_ADD);
				GL.blendFunc(GL.ZERO, GL.SRC_ALPHA);
			}
			
			Stage._curBMD = bmd;
		}
	}
	
	private function _getMakeTouch(id:Int) {  
		var t = this._touches["t" + id];
		if (t == null) {  
			t = { touch: null, target: null, act: 0 };  
			this._touches["t" + id] = t;
		}
		
		return t;
	}
	
	// touch events
	
	/*Stage._onTD = function(e){ 
		Stage._setStageMouse(e.touches.item(0)); Stage._main._smd[0] = true; Stage._main._knM = true;
		
		var main = Stage._main;
		for(var i=0; i<e.changedTouches.length; i++)
		{
			var tdom = e.changedTouches.item(i);
			var t = main._getMakeTouch(tdom.identifier);
			t.touch = tdom;
			t.act = 1;
		}
		main._processMouseTouch();
	}
	Stage._onTM = function(e){ 
		Stage._setStageMouse(e.touches.item(0)); Stage._main._smm    = true; Stage._main._knM = true;
		var main = Stage._main;
		for(var i=0; i<e.changedTouches.length; i++)
		{
			var tdom = e.changedTouches.item(i);
			var t = main._getMakeTouch(tdom.identifier);
			t.touch = tdom;
			t.act = 2;
		}
		main._processMouseTouch();
	}
	Stage._onTU = function(e){ 
		Stage._main._smu[0] = true; Stage._main._knM = true;
		var main = Stage._main;
		for(var i=0; i<e.changedTouches.length; i++)
		{
			var tdom = e.changedTouches.item(i);
			var t = main._getMakeTouch(tdom.identifier);
			t.touch = tdom;
			t.act = 3;
		}
		main._processMouseTouch();
	}*/
	
	// mouse events
	
	public function _onMD(button:Int, x:Int, y:Int) { 
		this._setStageMouse(x, y); 
		this._smd[button] = true; 
		this._knM = true;  
		this._processMouseTouch(); 
	}
	public function _onMM(x:Int, y:Int) { 
		this._setStageMouse(x, y); 
		this._smm = true; 
		this._knM = true;  
		this._processMouseTouch(); 
	}
	public function _onMU(button:Int) { 
		this._smu[button] = true; 
		this._knM = true;  
		this._processMouseTouch(); 
	}
	
	// keyboard events
	
	public function _onKD(altKey:Bool, ctrlKey:Bool, shiftKey:Bool, keyCode:Int, charCode:Int) { 
		var ev = new KeyboardEvent(KeyboardEvent.KEY_DOWN, true);
		ev._setFromDom(altKey, ctrlKey, shiftKey, keyCode, charCode);
		if (this.focus != null && this.focus.stage != null) {
			this.focus.dispatchEvent(ev); 
		}
		else {
			this.dispatchEvent(ev);
		}
	}
	
	private function _onKU(altKey:Bool, ctrlKey:Bool, shiftKey:Bool, keyCode:Int, charCode:Int) { 
		var ev = new KeyboardEvent(KeyboardEvent.KEY_UP, true);
		ev._setFromDom(altKey, ctrlKey, shiftKey, keyCode, charCode);
		if (this.focus != null && this.focus.stage != null) {
			this.focus.dispatchEvent(ev); 
		}
		else {
			this.dispatchEvent(ev);
		}
	}
	
	public function _onRS(_) { 
		this._srs = true;
	}	
	
	public function _getDPR():Float {
		return _dpr;
	}
	
	public function _resize() {		
		this._setFramebuffer(null, this.stageWidth, this.stageHeight, false);
	}

    private function _getShader(gl, str:String, fs:Bool) {	
        var shader:GLShader = null;
        if (fs)	{
			shader = GL.createShader(GL.FRAGMENT_SHADER);
		}
        else {
			shader = GL.createShader(GL.VERTEX_SHADER);   
		}
		
        GL.shaderSource(shader, str);
        GL.compileShader(shader);
		
        if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0) {
            trace(GL.getShaderInfoLog(shader));
            return null;
        }
		
        return shader;
    }

    private function _initShaders() {	
		var fs = [
			"precision mediump float;",
			"varying vec2 texCoord;",
			
			"uniform sampler2D uSampler;",
			"uniform vec4 color;",
			"uniform bool useTex;",
			
			"uniform mat4 cMat;",
			"uniform vec4 cVec;",
			
			"void main(void) {",
				"vec4 c;",
				"if (useTex) { c = texture2D(uSampler, texCoord);  c.xyz *= (1.0 / c.w); }",
				"else c = color;",
				"c = (cMat * c) + cVec;",
				"c.xyz *= min(c.w, 1.0);",
				"gl_FragColor = c;",
			"}"
		].join("\n");
		
		var vs = [
			"attribute vec3 verPos;",
			"attribute vec2 texPos;",
			
			"uniform mat4 tMat;",
			
			"varying vec2 texCoord;",
			
			"void main(void) {",
			"	gl_Position = tMat * vec4(verPos, 1.0);",
			"	texCoord = texPos;",
			"}"
		].join("\n");
		
		var fShader = this._getShader(GL, fs, true );
        var vShader = this._getShader(GL, vs, false);
		
		this._sprg = new WebGLProgram();
        this._sprg.prog = GL.createProgram();
        GL.attachShader(this._sprg.prog, vShader);
        GL.attachShader(this._sprg.prog, fShader);
        GL.linkProgram(this._sprg.prog);
		
        if (GL.getProgramParameter(this._sprg.prog, GL.LINK_STATUS) == 0) {
            trace("Could not initialise shaders");
        }
		
        GL.useProgram(this._sprg.prog);
		
        this._sprg.vpa		= GL.getAttribLocation(this._sprg.prog, "verPos");
        this._sprg.tca		= GL.getAttribLocation(this._sprg.prog, "texPos");
        GL.enableVertexAttribArray(this._sprg.tca);
		GL.enableVertexAttribArray(this._sprg.vpa);
		
		this._sprg.tMatUniform		= GL.getUniformLocation(this._sprg.prog, "tMat");
		this._sprg.cMatUniform		= GL.getUniformLocation(this._sprg.prog, "cMat");
		this._sprg.cVecUniform		= GL.getUniformLocation(this._sprg.prog, "cVec");
        this._sprg.samplerUniform	= GL.getUniformLocation(this._sprg.prog, "uSampler");
		this._sprg.useTex			= GL.getUniformLocation(this._sprg.prog, "useTex");
		this._sprg.color			= GL.getUniformLocation(this._sprg.prog, "color");
    }
	
    private function _initBuffers() {
        this._unitIBuffer = GL.createBuffer();
		
		Stage._setEBF(this._unitIBuffer);
        GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, new UInt16Array([0, 1, 2, 1, 2, 3]), GL.STATIC_DRAW);
    }
	
	public function _setFramebuffer(fbo:GLFramebuffer, w:Int, h:Int, flip:Bool) {
		this._mstack.clear();
		
		this._mstack.push(this._pmat);
		if (flip) { 
			this._umat[5]  =  2; 
			this._umat[13] = -1;
		}
		else { 
			this._umat[5]  = -2; 
			this._umat[13] =  1;
		}
		this._mstack.push(this._umat);
		
		this._smat[0] = 1 / w;  
		this._smat[5] = 1 / h;
		this._mstack.push(this._smat);
		
		GL.bindFramebuffer(GL.FRAMEBUFFER, fbo);
		if (fbo != null) {
			GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, w, h);
		}
		//GL.viewport(0, 0, w, h);
	}
	
	private function _setStageMouse(x:Int, y:Int) {	// event, want X
		var dpr = this._getDPR();
		this._mouseX = Std.int(x * dpr);
		this._mouseY = Std.int(y * dpr);
	}

    public function _drawScene() {		
		if (this._srs) {
			this._resize();
			this.dispatchEvent(new Event(Event.RESIZE));
			this._srs = false;
		}
		
		GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);	
		
		//	proceeding EnterFrame
		var efs = EventDispatcher.efbc;
		var ev = new Event(Event.ENTER_FRAME, false);
		for(i in 0...efs.length) {
			ev.target = efs[i];
			efs[i].dispatchEvent(ev);
		}
		
        this._renderAll(this);
    }
	
	private function _processMouseTouch() {
		if (this._knM) {
			var org = this._svec4_0;
			this._getOrigin(org);
			var p   = this._svec4_1;
			p[0] = this._mouseX;
			p[1] = this._mouseY;  
			p[2] = 0;  
			p[3] = 1;
			
			//	proceeding Mouse Events
			var newf = this._getTarget(org, p);
			var fa = this._mousefocus != null ? this._mousefocus : this;
			var fb = newf != null ? newf : this;
			
			if(newf != this._mousefocus) {
				if(fa != this) {
					var ev = new MouseEvent(MouseEvent.MOUSE_OUT, true);
					ev.target = fa;
					fa.dispatchEvent(ev);
				}
				if(fb != this) {
					var ev = new MouseEvent(MouseEvent.MOUSE_OVER, true);
					ev.target = fb;
					fb.dispatchEvent(ev);
				}
			}
			
			if (this._smd[0] && this.focus != null && newf != this.focus) {
				this.focus._loseFocus();
			}
			
			for (i in 0...3) {
				this._mcEvs[i].target = this._mdEvs[i].target = this._muEvs[i].target = fb;
				if (this._smd[i]) {
					fb.dispatchEvent(this._mdEvs[i]); 
					this._focii[i] = this.focus = newf;
				}
				
				if (this._smu[i]) {
					fb.dispatchEvent(this._muEvs[i]); 
					if (newf == this._focii[i]) {
						fb.dispatchEvent(this._mcEvs[i]); 
					}
				}
				this._smd[i] = this._smu[i] = false;
			}
			
			if (this._smm) { 
				var ev = new MouseEvent(MouseEvent.MOUSE_MOVE, true); 
				ev.target = fb;  
				fb.dispatchEvent(ev);  
				this._smm = false;
			}
			
			this._mousefocus = newf;
			
			//	checking buttonMode
			var uh = false;
			var ob = fb;
			while (ob.parent != null) {
				uh = cast(ob, InteractiveObject).buttonMode; 
				ob = ob.parent;
			}
			/*var cursor = uh?"pointer":"default";
			if(fb instanceof TextField && fb.selectable) cursor = "text"
			this._canvas.style.cursor = cursor;*/
		}
		
		var dpr = this._getDPR();
		for(tind in this._touches) {
			var t = this._touches[tind];
			if (t.act == 0) {
				continue;
			}
			
			var org = this._svec4_0;
			this._getOrigin(org);
			var p = this._svec4_1;
			p[0] = t.touch.clientX * dpr;  
			p[1] = t.touch.clientY * dpr;  
			p[2] = 0;  
			p[3] = 1;
			
			var newf = this._getTarget(org, p);
			var fa:Stage = t.target != null ? t.target : this;
			var fb = newf != null ? newf : this;
			
			if(newf != t.target) {
				if(fa != this) {
					var ev = new TouchEvent(TouchEvent.TOUCH_OUT, true);
					ev._setFromDom(t.touch);
					ev.target = fa;
					fa.dispatchEvent(ev);
				}
				if(fb != this) {
					var ev = new TouchEvent(TouchEvent.TOUCH_OVER, true);
					ev._setFromDom(t.touch);
					ev.target = fb;
					fb.dispatchEvent(ev);
				}
			}
			
			var ev:TouchEvent = null;
			if (t.act == 1) {
				ev = new TouchEvent(TouchEvent.TOUCH_BEGIN, true);
			}
			if (t.act == 2) {
				ev = new TouchEvent(TouchEvent.TOUCH_MOVE, true);
			}
			if (t.act == 3) {
				ev = new TouchEvent(TouchEvent.TOUCH_END, true);
			}
			ev._setFromDom(t.touch);
			ev.target = fb;
			fb.dispatchEvent(ev);
			if(t.act == 3 && newf == t.target) {
				ev = new TouchEvent(TouchEvent.TOUCH_TAP, true);
				ev._setFromDom(t.touch);
				ev.target = fb;
				fb.dispatchEvent(ev);
			}
			t.act = 0;
			t.target = (t.act == 3) ? null : newf;
		}
	}
	
}
