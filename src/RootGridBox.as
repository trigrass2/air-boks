package {
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filters.BitmapFilterQuality;
	import flash.filters.DropShadowFilter;
	
	import mx.events.ResizeEvent;
	public class RootGridBox extends GridBox {
		public var showGrid:Boolean=false;
		public function RootGridBox(app:Boks) {
			super(app);
			isRoot=true;
			removeChild(lbl);
			addEventListener(ResizeEvent.RESIZE, resizeBGGrid);
			filters=[new DropShadowFilter(4, 90, 0, .2, 14, 14, 1, BitmapFilterQuality.HIGH)];
		}
		protected function resizeBGGrid(e:ResizeEvent):void {
			if (app.colWidth==0) return;
			updateGrid();
		}
		// On écrase certaines fonctions
		override protected function onLayoutChange(e:GridEvent):void {}
		override protected function storeLayoutProps(pLeft:uint, pSpan:uint):void {}
		override protected function updateLabel():void {}
		/*override public function updateHeight(e:Event=null):void {
			graphics.clear();
			super.updateHeight(e);
			updateGrid();
		}*/
		//
		public function updateGrid():void {
			var pageWidth:uint=app.numCol*(app.colWidth+app.gutterWidth)-app.gutterWidth;
			//Application.application.status="Page width: "+pageWidth;
			width=pageWidth;
			//
			graphics.clear();
			graphics.beginBitmapFill(getGridBitmap());
			graphics.drawRect(0, 0, width, height);
		}
		public function getGridBitmap(forRootGrid:Boolean=true):BitmapData {
			var pattern:Sprite=new Sprite();
			var patternHeight:uint=forRootGrid ? app.boxHeight : app.lineHeight;
			var gPat:Graphics=pattern.graphics;
			// La colonne
			gPat.beginFill(0xdddddd);
			gPat.drawRect(0, 0, app.colWidth, patternHeight);
			// Le fond
			gPat.beginFill(0xeeeeee);
			gPat.drawRect(app.colWidth, 0, app.gutterWidth, patternHeight);
			// La baseline
			if (forRootGrid || app.showBaseline) {
				gPat.beginFill(0x999999);
				gPat.drawRect(0, patternHeight-1, app.colGut, 1);
			}
			//
			var bmp:BitmapData=new BitmapData(app.colGut, patternHeight);
			bmp.draw(pattern);
			return bmp;
		}
		override public function select():void {
			selectNone();
		}
		override public function getHTML():XML {
			var xml:XML=super.getHTML();
			xml.@["class"]="container";
			if (showGrid) xml.@["class"]+=" showgrid";
			return xml;
		}
		/*override protected function onChildAdd(e:ChildExistenceChangedEvent):void {
			super.onChildAdd(e);
			e.relatedObject.addEventListener(MoveEvent.MOVE, dispatchMinCol);
			e.relatedObject.addEventListener(ResizeEvent.RESIZE, dispatchMinCol);
			dispatchMinCol(e);
		}
		override protected function onChildRemove(e:ChildExistenceChangedEvent):void {
			super.onChildRemove(e);
			e.relatedObject.removeEventListener(MoveEvent.MOVE, dispatchMinCol);
			e.relatedObject.removeEventListener(ResizeEvent.RESIZE, dispatchMinCol);
			dispatchMinCol(e);
		}
		protected function dispatchMinCol(e:Event):void {
			// On parcourt les enfants pour voir lequel va le plus à droite...
			var minCol:uint=1;
			var boxes:Array=getBoxes();
			for (var i:uint=0; i<boxes.length; i++) {
				var box:GridBox=boxes[i];
				// Si un objet vient d'être enlevé, on l'ignore
				if (e.type==ChildExistenceChangedEvent.CHILD_REMOVE && (e as ChildExistenceChangedEvent).relatedObject==box) continue;
				// On ignore les boites qui sont "souples" (celles qui ne doivent pas nécessairement faire la largeur du parent)
				if (box.type!=GridBox.DIV) continue;
				minCol=Math.max(minCol, box.left+box.span); 
			}
			//if (minCol==0) minCol=app.numCol;
			trace(minCol);
			var ev:GridEvent=new GridEvent(GridEvent.ROOT_CHILD_CHANGE);
			ev.data=minCol;
			dispatchEvent(ev);
		}*/
		public function getMinimumColNum():uint {
			var minCol:uint=1;
			var boxes:Array=getBoxes();
			for (var i:uint=0; i<boxes.length; i++) {
				var box:GridBox=boxes[i];
				// On ignore les boites qui sont "souples" (celles qui ne doivent pas nécessairement faire la largeur du parent)
				if (box.type!=GridBox.DIV) continue;
				minCol=Math.max(minCol, box.left+box.span); 
			}
			return minCol;
		}
		override public function buildFromObject(o:Object, pApp:Boks):void {
			var boxes:Array=getBoxes();
			for (var i:uint=0; i<boxes.length; i++) {
				boxes[i].dispose();
			}
			super.buildFromObject(o, pApp);
		}
	}
}