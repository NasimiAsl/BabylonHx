BabylonHx Demos
=========
'''html
<style>
	div[data-container] div.img{
		width:196px !important;
		height:196px !important;
	}
</style>
<div style="width:100%; float:left" data-container='true'>
	<div style="width:196px; float:left">
	  <a href="http://babylonhx.github.io/webvr_materials/" target="_blank" />
		<img src="http://babylonhx.github.io/webvr_materials/webvr_materials.jpg" style="float:left; width:196px; height:196px" />
		</a>
	</div>
	<div style="width:196px; float:left">
	  <a href="http://babylonhx.github.io/ProceduralTextures/" target="_blank" />
		<img src="http://babylonhx.github.io/ProceduralTextures/ProceduralTextures.jpg" style="float:left; width:196px; height:196px" />
		</a>
	</div>
	<div style="width:196px; float:left">
	  <a href="http://babylonhx.github.io/Fresnel/" target="_blank" />
		<img src="http://babylonhx.github.io/Fresnel/Fresnel.jpg" style="float:left; width:196px; height:196px" />
		</a>
	</div>
	<div style="width:196px; float:left">
	  <a href="http://babylonhx.github.io/DisplacementMap/" target="_blank" />
		<img src="http://babylonhx.github.io/DisplacementMap/DisplacementMap.jpg" style="float:left; width:196px; height:196px" />
		</a>
	</div>
	<div style="width:196px; float:left">
	  <a href="http://babylonhx.github.io/heightmap/" target="_blank" />
		<img src="http://babylonhx.github.io/heightmap/heightmap.jpg" style="float:left; width:196px; height:196px" />
		</a>
	</div>
</div>
'''

BabylonHx
=========

BabylonHx is a direct port of BabylonJs engine to Haxe, compatible with [Snow](https://github.com/underscorediscovery/snow),  [Lime](https://github.com/openfl/lime) and [NME](https://github.com/haxenme/nme).
It supports (almost) all features of the original.

<img src="https://api.travis-ci.org/babylonhx/BabylonHx_2.0.svg" />


**Usage instructions:**

Download complete repo.
Navigate to the folder where files are downloaded.

To build for Snow run from command line:

***haxelib run flow run web***

To build for Lime run from command line:

***haxelib run lime run project.xml html5***

To build for NME run from command line:

***haxelib run nme run build.xml windows***

You should see this in your browser when build is done:
![Alt text](scrshot.jpg?raw=true "Basic scene")

Snow binaries are located in bin_snow folder and Lime binaries are located in bin_lime folder.

You can get assets required by other samples from Babylon.js samples repo https://github.com/BabylonJS/Samples

Visit http://babylonhx.com/ for more info about the engine.
