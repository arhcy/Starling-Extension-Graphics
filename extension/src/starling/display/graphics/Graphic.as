package starling.display.graphics
{
	import flash.display3D.Context3D;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	import starling.display.Mesh;
	import starling.rendering.MeshStyle;
	import starling.rendering.VertexData
	import starling.rendering.IndexData;
	//import starling.display.geom.GraphicsPolygon;
	//import starling.display.graphics.util.IGraphicDrawHelper;
	import starling.geom.Polygon;
	
	import starling.core.Starling;
	import starling.display.BlendMode;
	import starling.display.DisplayObject;
	import starling.errors.AbstractMethodError;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.utils.MathUtil;
	import starling.textures.Texture;
	import starling.textures.SubTexture;
	
	
	/**
	 * Abstract, do not instantiate directly
	 * Used as a base-class for all the drawing API sub-display objects (Like Fill and Stroke).
	 */
	public class Graphic extends Mesh
	{
		protected static const VERTEX_STRIDE		:int = 9;
		protected static var sHelperMatrix			:Matrix = new Matrix();
		
		protected var vertices		:Vector.<Number>;
		protected var indices		:Vector.<uint>;
		protected var _uvMatrix		:Matrix;
		
		protected var buffersInvalid		:Boolean = false;
		protected var geometryInvalid		:Boolean = false;
		protected var uvsInvalid	:Boolean = false;
		protected var uvMappingsChanged:Boolean = false;
		protected var isGeometryScaled:Boolean = false;
		
		
	//	protected var hasValidatedGeometry:Boolean = false;
				
		private static var sGraphicHelperRect:Rectangle = new Rectangle();
		private static var sGraphicHelperPoint:Point = new Point();
		private static var sGraphicHelperPointTR:Point = new Point();
		private static var sGraphicHelperPointBL:Point = new Point();
		
		// Filled-out with min/max vertex positions
		// during addVertex(). Used during getBounds().
		protected var minBounds			:Point;
		protected var maxBounds			:Point;
		
		// used for geometry level hit tests. False gives boundingbox results, True gives geometry level results. 
		// True is a lot more exact, but also slower.
		protected var _precisionHitTest:Boolean = false;
		protected var _precisionHitTestDistance:Number = 0; // This is added to the thickness of the line when doing precisionHitTest to make it easier to hit 1px lines etc
		
		// Attempt to allow partial rendering of graphics. Mostly useful for Strokes, I would guess.
		//protected var _graphicDrawHelper:IGraphicDrawHelper = null;
					
		public function Graphic(style:MeshStyle = null)
		{
			indices = new Vector.<uint>();
			vertices = new Vector.<Number>();
			
			minBounds = new Point();
			maxBounds = new Point();
			
			super(new VertexData(MeshStyle.VERTEX_FORMAT, 3),  new IndexData(3), style);
		}
		
		
		
		override public function dispose():void
		{

			vertices = null;
			indices = null;
			_uvMatrix = null;
			minBounds = null;
			maxBounds = null;			
			geometryInvalid = true;
		}
		
		public function get uvMatrix():Matrix
		{
			return _uvMatrix;
		}
		
		public function set uvMatrix(value:Matrix):void
		{
			_uvMatrix = value;
			uvsInvalid = true;
			geometryInvalid = true;
		}
		
		
		public function shapeHitTest( stageX:Number, stageY:Number ):Boolean
		{
			var pt:Point = globalToLocal(new Point(stageX,stageY));
			return pt.x >= minBounds.x && pt.x <= maxBounds.x && pt.y >= minBounds.y && pt.y <= maxBounds.y;
		}
		
		public function set precisionHitTest(value:Boolean) : void
		{
			_precisionHitTest = value;
		}
		public function get precisionHitTest() : Boolean 
		{
			return _precisionHitTest;
		}
		public function set precisionHitTestDistance(value:Number) : void
		{
			_precisionHitTestDistance = value;
		}
		public function get precisionHitTestDistance() : Number
		{
			return _precisionHitTestDistance;
		}
		
		protected function shapeHitTestLocalInternal( localX:Number, localY:Number ):Boolean
		{
			return localX >= (minBounds.x-_precisionHitTestDistance) && localX <= (maxBounds.x+_precisionHitTestDistance) && localY >= (minBounds.y-_precisionHitTestDistance) && localY <= (maxBounds.y+_precisionHitTestDistance);
		}
		
		/** Returns the object that is found topmost beneath a point in local coordinates, or nil if 
         *  the test fails. If "forTouch" is true, untouchable and invisible objects will cause
         *  the test to fail. */
        /*override public function hitTest(localPoint:Point, forTouch:Boolean=false):DisplayObject
        {
            // on a touch test, invisible or untouchable objects cause the test to fail
            if (forTouch && (visible == false || touchable == false )) return null;
            if ( minBounds == null || maxBounds == null ) return null;
			
			// otherwise, check bounding box
			if (getBounds(this, sGraphicHelperRect).containsPoint(localPoint))
			{
				if ( _precisionHitTest )
				{
					if ( shapeHitTestLocalInternal(localPoint.x, localPoint.y ) )
						return this;
				}
				else
					return this;
			}
				
			return null;
			
        }*/
		
		override public function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if (resultRect == null) 
				resultRect = new Rectangle();
			
			if (targetSpace == this) // optimization
			{
				resultRect.x = minBounds.x;
				resultRect.y = minBounds.y;
				resultRect.right = maxBounds.x;
				resultRect.bottom = maxBounds.y; 
				if ( _precisionHitTest )
				{	
					resultRect.x -= _precisionHitTestDistance;
					resultRect.y -= _precisionHitTestDistance;
					resultRect.width += _precisionHitTestDistance * 2;
					resultRect.height += _precisionHitTestDistance * 2;
				}
				
				return resultRect;
			}
						
			getTransformationMatrix(targetSpace, sHelperMatrix);
			var m:Matrix = sHelperMatrix;
			
			sGraphicHelperPointTR.x = minBounds.x + (maxBounds.x - minBounds.x)
			sGraphicHelperPointTR.y = minBounds.y;
			sGraphicHelperPointBL.x = minBounds.x;
			sGraphicHelperPointBL.y =  minBounds.y + (maxBounds.y - minBounds.y);
			/*
			 * Old version, 2 point allocations
			 * var tr:Point = new Point(minBounds.x + (maxBounds.x - minBounds.x), minBounds.y);
			 * var bl:Point = new Point(minBounds.x , minBounds.y + (maxBounds.y - minBounds.y));
			 */ 
			
			var TL:Point = sHelperMatrix.transformPoint(minBounds);
			sGraphicHelperPointTR = sHelperMatrix.transformPoint(sGraphicHelperPointTR);
			var BR:Point = sHelperMatrix.transformPoint(maxBounds);
			sGraphicHelperPointBL = sHelperMatrix.transformPoint(sGraphicHelperPointBL);
		
			/*
			 * Old version, 2 point allocations through clone
			 var TL:Point = sHelperMatrix.transformPoint(minBounds.clone());
			 tr = sHelperMatrix.transformPoint(bl);
			 var BR:Point = sHelperMatrix.transformPoint(maxBounds.clone());
			 bl = sHelperMatrix.transformPoint(bl);
			*/
			
			
			resultRect.x = Math.min(TL.x, BR.x, sGraphicHelperPointTR.x, sGraphicHelperPointBL.x);
			resultRect.y = Math.min(TL.y, BR.y, sGraphicHelperPointTR.y, sGraphicHelperPointBL.y);
			resultRect.right = Math.max(TL.x, BR.x, sGraphicHelperPointTR.x, sGraphicHelperPointBL.x);
			resultRect.bottom = Math.max(TL.y, BR.y, sGraphicHelperPointTR.y, sGraphicHelperPointBL.y);
			if ( _precisionHitTest )
			{
				resultRect.x -= _precisionHitTestDistance;
				resultRect.y -= _precisionHitTestDistance;
				resultRect.width += _precisionHitTestDistance * 2;
				resultRect.height += _precisionHitTestDistance * 2;
			}
			return resultRect;
		}
		
		protected function buildGeometry():void
		{
			throw( new AbstractMethodError() );
		}
		
		public function applyUVMatrix():void
		{
			if ( !vertices ) return;
			if ( !_uvMatrix ) return;
			
			var uv:Point = new Point();
			for ( var i:int = 0; i < vertices.length; i += VERTEX_STRIDE )
			{
				uv.x = vertices[i+7];
				uv.y = vertices[i+8];
				uv = _uvMatrix.transformPoint(uv);
				vertexData.setPoint(int(i / VERTEX_STRIDE), "texCoords", uv.x, uv.y);
				/*vertices[i+7] = uv.x;
				vertices[i+8] = uv.y;*/
			}
		}
		
		public function adjustUVMappings(x:Number, y:Number, texture:Texture) : void
		{
			
			var w:Number = MathUtil.getNextPowerOfTwo(texture.nativeWidth);
			var h:Number = MathUtil.getNextPowerOfTwo(texture.nativeHeight);
			
			var invW:Number = 1.0 / w;
			var invH:Number = 1.0 / h;
			
			var vertX:Number;
			var vertY:Number;
			var u:Number;
			var v:Number;
			
			if ( vertices == null || vertices.length == 0 )
				return;
			var numVerts:int = vertices.length;	
			for ( var i:int = 0; i < numVerts; i += VERTEX_STRIDE )
			{
				vertX = vertices[i];
				vertY = vertices[i+1];
				
				u = (x + vertX) * invW;
				v = (y + vertY) * invH;
				
				vertices[i+7] = u;
				vertices[i+8] = v;
			}
			
			uvMappingsChanged = true;
			_uvMatrix = null;
			
		}
		
		
		public function validateNow():void
		{
			if ( geometryInvalid == false && uvMappingsChanged == false )
				return;
			
			/*if ( vertexBuffer && (buffersInvalid || uvsInvalid || isGeometryScaled ) )
			{
				vertexBuffer.dispose();
				indexBuffer.dispose();
			}*/
			
			if ( buffersInvalid || geometryInvalid )
			{
				buildGeometry();
				applyUVMatrix();
			}
			else if ( uvsInvalid )
			{
				applyUVMatrix();
			}
		}
		
		protected function setGeometryInvalid(invalidateBuffers:Boolean = true) : void
		{
			if ( invalidateBuffers )
				buffersInvalid = true;
			geometryInvalid = true;
		}
		
		
		/*
		public function exportToPolygon(prevPolygon:GraphicsPolygon = null) : GraphicsPolygon
		{
			validateNow();
			
			var startIndex:int = 0;
			var startIndices:int = 0;
			
			if ( prevPolygon )
			{
				startIndex = prevPolygon.lastVertexIndex <= 0 ? 0 : prevPolygon.lastVertexIndex * VERTEX_STRIDE;
				startIndices = prevPolygon.lastIndexIndex <= 0 ? 0 : prevPolygon.lastIndexIndex * VERTEX_STRIDE;
			}
			
			var newVertArray:Array = new Array();
			var vertLen:int = vertices.length;
			
			for ( var i:int = startIndex; i < vertLen; i += VERTEX_STRIDE )
			{
				newVertArray.push(vertices[i + 0]);
				newVertArray.push(vertices[i + 1]);
			}
			
			if ( prevPolygon == null )
			{
				var retval:GraphicsPolygon = new GraphicsPolygon(newVertArray, indices);
				return retval;
			}
			else
			{
				prevPolygon.append(newVertArray, indices);
				return prevPolygon;
			}
			
		}*/
		

		/*public function set graphicDrawHelper(gdh:IGraphicDrawHelper) : void
		{
			validateNow();
			_graphicDrawHelper = gdh;
			_graphicDrawHelper.initialize(vertices.length / VERTEX_STRIDE);
		}
		
		public function get graphicDrawHelper() : IGraphicDrawHelper
		{
			return _graphicDrawHelper;
		}*/
		
	}
}