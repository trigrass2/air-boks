package {
	import flash.display.Graphics;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.ui.Keyboard;
	
	import mx.containers.Canvas;
	import mx.controls.Label;
	import mx.core.ScrollPolicy;
	import mx.events.ChildExistenceChangedEvent;
	import mx.events.ResizeEvent;
	import mx.utils.StringUtil;
	//
	public class GridBox extends Canvas {
		public static var selectionWatcher:EventDispatcher;
		protected static var selectedBox:GridBox;
		//
		public var app:Boks;
		protected var isRoot:Boolean=false;
		//
		protected var lbl:Label;
		protected var drawGhost:Canvas;
		protected var drawStart:Point;
		protected var drawRect:Rectangle;
		protected var drawRectIsAllowed:Boolean;
		//
		protected var _domID:String=''; 
		protected var _type:String=GridBox.DIV;
		protected var _moreClasses:String='';
		protected var _htmlContent:String='';
		protected var _border:uint=0;
		//
		public static const DIV:String="div";
		public static const P:String="p";
		public static const BLOCKQUOTE:String="blockquote";
		public static const H1:String="h1";
		public static const H2:String="h2";
		public static const H3:String="h3";
		public static const H4:String="h4";
		public static const H5:String="h5";
		public static const H6:String="h6";
		public static const HR:String="hr";
		//
		protected var creating:Boolean;
		//
		public static const allBoxesTypes:Array=[GridBox.DIV, GridBox.P, GridBox.BLOCKQUOTE, GridBox.H1, GridBox.H2, GridBox.H3, GridBox.H4, GridBox.H5, GridBox.H6, GridBox.HR];
		public static const nonParentWideTypes:Array=[GridBox.DIV/*, GridBox.P, GridBox.BLOCKQUOTE, GridBox.H1, GridBox.H2, GridBox.H3, GridBox.H4, GridBox.H5, GridBox.H6*/];
		public static const filledBoxesTypes:Array=[GridBox.DIV];
		//
		public static const exportableProps:Array=['left', 'span', 'top', 'domID', 'type', 'htmlContent', 'moreClasses', 'border'];
		//
		public function GridBox(pApp:Boks) {
			if (!selectionWatcher) selectionWatcher=new EventDispatcher();
			super();
			horizontalScrollPolicy=ScrollPolicy.OFF;
			horizontalScrollBar=null;
			//
			app=pApp;
			height=minHeight=app.boxHeight;
			drawGhost=new Canvas();
			addChild(drawGhost);
			addEventListener(Event.ADDED_TO_STAGE, onAdd);
			//
			lbl=new Label();
			lbl.mouseChildren=false;
			lbl.mouseEnabled=false;
			lbl.setStyle('color', 0xffffff);
			addChild(lbl);
			//
			refreshBorderSprite();
			updateLabel();
			addEventListener(ResizeEvent.RESIZE, refreshToolTip);
		}
		protected function onAdd(e:Event):void {
			storeLayoutProps(left, span);
			addEventListener(MouseEvent.MOUSE_DOWN, startDrawSelection);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, handleShortcut);
			//addEventListener(MouseEvent.CLICK, onClick);
			addEventListener(ChildExistenceChangedEvent.CHILD_ADD, onChildAdd);
			addEventListener(ChildExistenceChangedEvent.CHILD_REMOVE, onChildRemove);
			app.addEventListener(GridEvent.LAYOUT_CHANGE, onLayoutChange);
			addEventListener(Event.REMOVED_FROM_STAGE, onRemove);
			addEventListener(ResizeEvent.RESIZE, refreshBorderSprite);
		}
		protected function onRemove(e:Event):void {
			removeEventListener(MouseEvent.MOUSE_DOWN, startDrawSelection);
			stage.removeEventListener(KeyboardEvent.KEY_DOWN, handleShortcut);
			//removeEventListener(MouseEvent.CLICK, onClick);
			removeEventListener(ChildExistenceChangedEvent.CHILD_ADD, onChildAdd);
			removeEventListener(ChildExistenceChangedEvent.CHILD_REMOVE, onChildRemove);
			app.removeEventListener(GridEvent.LAYOUT_CHANGE, onLayoutChange);
			removeEventListener(Event.REMOVED_FROM_STAGE, onRemove);
			removeEventListener(ResizeEvent.RESIZE, refreshBorderSprite);
		}
		protected function magnetX(n:Number):int {
			return app.colGut*Math.floor(n/app.colGut);
		}
		protected function magnetY(n:Number):int {
			return app.boxHeight*Math.floor(n/app.boxHeight);
		}
		protected function magnetWidth(n:Number):int {
			return app.colGut*Math.ceil(n/app.colGut)-app.gutterWidth/*)*/;
		}
		protected function mouseEventTargetIsOK(e:MouseEvent):Boolean {
			// Cas particulier, quand il devrait y avoir une scrollbar
			// le click ne se fait pas directement sur le boite mais sur son 'contentPane'
			return (e.target==e.currentTarget || (e.target.name=='contentPane' && e.target.parent==this));
		}
		protected function startDrawSelection(e:MouseEvent):void {
			drawRectIsAllowed=true;
			drawStart=new Point(magnetX(mouseX), magnetY(mouseY));
			drawRect=null;
			//
			if (!mouseEventTargetIsOK(e)) return;
			// Les évenements
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onDrawSelectionChange);
			stage.addEventListener(MouseEvent.MOUSE_UP, stopDrawSelection);
		}
		protected function onDrawSelectionChange(e:MouseEvent):void {
			var g:Graphics=drawGhost.graphics;
			g.clear();
			var rtl:Boolean=drawStart.x>=mouseX;
			var drawStartX:uint=rtl ? magnetX(mouseX) : drawStart.x;
			var drawWidth:int=rtl ? magnetWidth(drawStart.x-mouseX+app.colGut) : magnetWidth(mouseX-drawStartX);
			drawRect=new Rectangle(drawStartX, drawStart.y, drawWidth, app.boxHeight);
			//
			if (rowIsEmpty(drawRect.y)) {
				drawRectIsAllowed=true;
				// Si la ligne est vide, on n'a le droit de dessiner que si il n'y y a pas une boite "remplie" qui descend jusque là
				var allBoxes:Array=getBoxes();
				for (var i:uint=0; i<allBoxes.length; i++) {
					var box:GridBox=allBoxes[i];
					if (box.y<drawRect.y && box.y+box.height>drawRect.y) drawRectIsAllowed=false;
				}
			} else {
				// La ligne n'est pas vide, on vérifie que le rectangle ne passe pas sur une boite
				drawRectIsAllowed=!drawGhostOverlapsBox();
			}
			// Il ne faut pas non plus dépasser la droite
			drawRectIsAllowed=drawRectIsAllowed && drawRect.x+drawRect.width<=(border==2 ? width-app.colGut : width);
			// Et si ce n'est pas une div, on refuse les enfants
			drawRectIsAllowed=drawRectIsAllowed && type==GridBox.DIV;
			//
			g.lineStyle(1, drawRectIsAllowed ? 0x000000 : 0xff0000, .8, true);
			g.drawRect(drawRect.x, drawRect.y, drawRect.width, drawRect.height);
			//
			e.updateAfterEvent();
		}
		protected function stopDrawSelection(e:MouseEvent):void {
			// On vire le ghost et les évenements
			drawGhost.graphics.clear();
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDrawSelectionChange);
			stage.removeEventListener(MouseEvent.MOUSE_UP, stopDrawSelection);
			if (!drawRectIsAllowed) return;
			if (!drawRect || drawRect.width<app.colWidth) {
				drawRect=null;
				// Si on n'a rien dessiné, on séléctionne cette boite !
				select();
				return;
			}
			//
			var box:GridBox=new GridBox(app);
			box.creating=true;
			box.x=drawRect.x;
			box.width=drawRect.width;
			box.refreshToolTip();
			box.y=drawRect.y;
			box.addEventListener(ResizeEvent.RESIZE, onChildResize);
			addChild(box);
			box.creating=false;
			box.select();
			//
			drawRect=null;
		}
		protected function onChildAdd(e:ChildExistenceChangedEvent):void {
			if (app.importing) return;
			var i:uint;
			var allBoxes:Array=getBoxes();
			var newBox:GridBox=e.relatedObject as GridBox;
			//
			if (getBoxesOnRow(newBox.y).length>1 && newBox.y>0) {
				// Si on a dessiné sur une ligne non vide qui n'est pas la première, rien à faire
				updateHeight(e);
				//return;
			} else if (newBox.y==height-app.boxHeight) {
				// Si la boite a été dessinée sur la dernière ligne, on la descend simplement pour pouvoir dessiner au dessus
				newBox.y+=app.boxHeight;
				updateHeight(e);
				//return;
			} else if (newBox.y==0) {
				// Si la boite a été dessinée sur la première ligne, on fait tout descendre
				for (i=0; i<allBoxes.length; i++) {
					if (allBoxes[i]==newBox) allBoxes[i].y+=app.boxHeight;
					else allBoxes[i].y+=app.boxHeight*2;
				}
				updateHeight(e);
				//return;
			} else {
				// Si on a dessiné ni sur la première ni sur la dernière ligne, il faut faire descendre les boite qui sont en dessous
				for (i=0; i<allBoxes.length; i++) {
					if (allBoxes[i].y>newBox.y && allBoxes[i]!=newBox)  allBoxes[i].y+=app.boxHeight*2;
				}
				newBox.y+=app.boxHeight;
				updateHeight(e);
			}
			updateLabel();
			app.storeHistoryStep(newBox, "Add Element");
		}
		protected function rowIsEmpty(py:uint):Boolean {
			return getBoxesOnRow(py).length==0;
		}
		protected function getBoxesOnRow(py:uint):Array {
			return getBoxes().filter(function(element:GridBox, index:int, arr:Array):Boolean {
				return element.y==py;
			});
		}
		protected function drawGhostOverlapsBox():Boolean {
			var onRow:Array=getBoxesOnRow(drawRect.y);
			for (var i:uint=0; i<onRow.length; i++) {
				var box:GridBox=onRow[i];
				if (drawRect.x>box.x && drawRect.x<box.x+box.width) return true;
				if (drawRect.x+drawRect.width<box.x+box.width && drawRect.x+drawRect.width>box.x) return true;
				if (drawRect.x<=box.x && drawRect.x+drawRect.width>=box.x+box.width) return true;
			}
			return false;
		}
		protected function onChildRemove(e:ChildExistenceChangedEvent):void {
			if (app.importing) return;
			if (!e.relatedObject is GridBox) return;
			updateLabel();
			var tg:GridBox=e.relatedObject as GridBox;
			var i:uint;
			var box:GridBox;
			var onRow:Array=getBoxesOnRow(tg.y);
			var boxes:Array=getBoxes();
			// Si la boite était la seule sur cette ligne, on fait remonter celles qui sont en dessous
			if (onRow.length==1) {
				for (i=0; i<boxes.length; i++) {
					box=boxes[i];
					if (box!=tg && box.y>tg.y) box.y-=tg.height+app.boxHeight;
				}
			} else {
				// La boite n'était pas la seule, on détermine de combien il faut remonter celles qui sont en dessous...
				var maxH:uint=getHighestHeightOnRow(tg);
				if (maxH<tg.height) {
					for (i=0; i<boxes.length; i++) {
						box=boxes[i];
						if (box.y>tg.y) box.y-=tg.height-maxH/*tg.height-e.oldHeight*/;
					}
				}
			}
			updateHeight(e);
		}
		protected function getHighestHeightOnRow(box:GridBox):uint {
			var onRow:Array=getBoxesOnRow(box.y);
			var maxH:uint=0;
			for (var i:uint=0; i<onRow.length; i++) {
				if (onRow[i]!=box && onRow[i].height>maxH) {
					maxH=onRow[i].height;
				}
			}
			return maxH;
		}
		protected function onChildResize(e:ResizeEvent):void {
			//if (app.importing) return;
			if (e.oldHeight==0) return;
			var tg:GridBox=e.target as GridBox;
			var maxH:uint=getHighestHeightOnRow(tg);
			// Si un objet grandit et qu'il ne devient pas le plus grand, on ignore
			if (tg.height>e.oldHeight && tg.height<=maxH) {
				updateHeight(e);
				return;
			}
			// Si un objet rétrécit et que le max est supérieur ou égal à sa taille précédente, on ignore
			if (tg.height<e.oldHeight && maxH>=e.oldHeight) {
				updateHeight(e);
				return;
			}
			// Sinon, il faut pousser les boites en dessous (de la différence)
			var boxes:Array=getBoxes();
			for (var i:uint=0; i<boxes.length; i++) {
				var box:GridBox=boxes[i];
				if (box.y>tg.y) box.y+=tg.height-e.oldHeight;
			}
			updateHeight(e);
		}
		public function updateHeight(e:Event=null):void {
			var maxY:uint=0;
			var boxes:Array=getBoxes();
			var calledOnRemove:Boolean=e is ChildExistenceChangedEvent && e.type==ChildExistenceChangedEvent.CHILD_REMOVE;
			// Si il n'y avait qu'une boite, on simplifie la chose
			if (calledOnRemove && boxes.length==1) {
				height=app.boxHeight;
				return;
			}
			for (var i:uint=0; i<boxes.length; i++) {
				var box:GridBox=boxes[i];
				// Si un objet est en train d'être supprimé on l'ignore
				if (calledOnRemove && ChildExistenceChangedEvent(e).relatedObject==box) continue;
				var yy:uint=box.y+box.height;
				if (yy>maxY) maxY=yy;
			}
			height=maxY+app.boxHeight;
			//trace('updateHeight', this, height);
		}
		protected function handleShortcut(e:KeyboardEvent):void {
			if (!selected || focusManager.getFocus()) return;
			if (e.keyCode==Keyboard.DELETE || e.keyCode==Keyboard.BACKSPACE) dispose();
			if (e.keyCode==Keyboard.LEFT) {
				if (e.shiftKey) expandLeft();
				else if (e.altKey) collapseRight();
				else slideLeft();
			}
			if (e.keyCode==Keyboard.RIGHT) {
				if (e.shiftKey) collapseLeft();
				else if (e.altKey) expandRight();
				else slideRight();
			}
		}
		public function leftIsEmpty():Boolean {
			return prepend>0;
		}
		public function rightIsEmpty():Boolean {
			return virtualAppend>0;
		}
		public function slideLeft(addToHistory:Boolean=true):void {
			if (leftIsEmpty()) {
				left--;
				if (addToHistory) storeHistoryStep("Move Element");
			}
		}
		public function slideRight():void {
			if (rightIsEmpty()) {
				left++;
				storeHistoryStep("Move Element");
			}
		}
		public function expandLeft():void {
			if (!leftIsEmpty()) return;
			slideLeft(false);
			span++;
			storeHistoryStep("Resize Element");
		}
		public function expandRight():void {
			if (rightIsEmpty()) {
				span++;
				storeHistoryStep("Resize Element");
			}
		}
		public function canCollapse():Boolean {
			if (type!=GridBox.DIV) return false;
			if (border==2) return span>2 && !childTouchesRight();
			return (span>1 && !childTouchesRight());
		}
		public function collapseLeft():void {
			if (!canCollapse()) return;
			left++;
			collapseRight();
		}
		public function collapseRight():void {
			if (!canCollapse()) return;
			span--;
			storeHistoryStep("Resize Element");
		}
		public static function selectNone():void {
			if (selectedBox) selectedBox.unselect();
		}
		public static function hasSelection():Boolean {
			return selectedBox!=null;
		}
		public static function getSelection():GridBox {
			return selectedBox;
		}
		public function get selected():Boolean {
			return selectedBox==this;
		}
		public function dispose():void {
			if (!parent) return;
			//(parent as GridBox).select();
			selectNone();
			parent.removeChild(this);
			storeHistoryStep("Remove Element");
		}
		public function unselect():void {
			setStyle('backgroundColor', 0x000000);
			selectedBox=null;
			selectionWatcher.dispatchEvent(new GridEvent(GridEvent.UNSELECT));
		}
		public function select():void {
			// On annule le focus éventuel
			if (stage) stage.focus=null;
			//
			if (selected) return;
			if (selectedBox) selectedBox.unselect();
			setStyle('backgroundColor', 0x0000ff);
			selectedBox=this;
			selectionWatcher.dispatchEvent(new GridEvent(GridEvent.SELECT));
		}
		protected var _oldLeft:uint;
		protected var _oldSpan:uint;
		protected function storeLayoutProps(pLeft:uint, pSpan:uint):void {
			_oldLeft=pLeft;
			_oldSpan=pSpan;
		}
		public function get left():uint {
			return x/app.colGut;
		}
		public function set left(n:uint):void {
			storeLayoutProps(n, _oldSpan);
			x=n*app.colGut;
			refreshBorderSprite();
			if (selected) selectionWatcher.dispatchEvent(new GridEvent(GridEvent.MOVE));
		}
		public function get right():uint {
			if (!(parent is GridBox)) return 0;
			return (parent as GridBox).span-left-span;
		}
		public function get span():uint {
			return (width+app.gutterWidth)/app.colGut;
		}
		public function set span(n:uint):void {
			storeLayoutProps(_oldLeft, n);
			width=n*app.colGut-app.gutterWidth;
			refreshToolTip();
			resizeNonDivChildren();
			refreshBorderSprite();
			if (selected) selectionWatcher.dispatchEvent(new GridEvent(GridEvent.RESIZE));
		}
		protected function refreshToolTip(e:Event=null):void {
			toolTip=width+'px';
		}
		public function getActualSpan():uint {
			if (border==2 && span>1) return span-1;
			return span;
		}
		protected function resizeNonDivChildren():void {
			var boxes:Array=getBoxes();
			for (var i:uint=0; i<boxes.length; i++) {
				if (boxes[i].type!=GridBox.DIV) boxes[i].span=span;
			}
		}
		public function refreshSpan():void {
			width=_oldSpan*app.colGut-app.gutterWidth;
		}
		public function get prepend():uint {
			var n:uint=left;
			var onRow:Array=getSiblingsOnRow();
			for (var i:uint=0; i<onRow.length; i++) {
				var sibling:GridBox=onRow[i];
				if (sibling.left<left) {
					n=left-sibling.left-sibling.span;
				}
			}
			return n;
		}
		public function get append():uint {
			if (!last) return 0;
			return calcAppend();
		}
		public function calcAppend():uint {
			var n:uint=right;
			var onRow:Array=getSiblingsOnRow().reverse();
			for (var i:uint=0; i<onRow.length; i++) {
				var sibling:GridBox=onRow[i];
				if (sibling.left>left) {
					n=sibling.left-left-span;
				}
			}
			if (!(parent is GridBox)) return n;
			return (parent as GridBox).border==2 ? n-1 : n;
		}
		public function get virtualAppend():uint {
			return calcAppend();
		}
		public function get last():Boolean {
			var onRow:Array=getSiblingsOnRow();
			for (var i:uint=0; i<onRow.length; i++) {
				if (onRow[i].left>left) return false;
			}
			return true;
		}
		public function get domID():String {
			return _domID;
		}
		public function set domID(s:String):void {
			if (_domID==s) return;
			_domID=s;
			updateLabel();
			storeHistoryStep("Change DOM id");
		}
		public function set type(s:String):void {
			if (_type==s) return;
			_type=s;
			updateLabel();
			storeHistoryStep("Change Markup Type");
		}
		public function get type():String {
			return _type;
		}
		public function set htmlContent(s:String):void {
			if (_htmlContent==s) return;
			_htmlContent=s;
			updateLabel();
			storeHistoryStep("Change HTML Content");
		}
		public function get htmlContent():String {
			return _htmlContent;
		}
		public function set moreClasses(s:String):void {
			if (_moreClasses==s) return;
			_moreClasses=s;
			storeHistoryStep("Change More Classes");
		}
		public function get moreClasses():String {
			return _moreClasses;
		}
		public function acceptsBorder():Boolean {
			return type==GridBox.DIV && right>0;
		}
		public function acceptsColBorder():Boolean {
			return span>1 && acceptsBorder() && !childTouchesRight();
		}
		public function get border():uint {
			return _border;
		}
		public function set border(n:uint):void {
			if (_border==n) return; 
			_border=n;
			refreshBorderSprite();
			storeHistoryStep("Change Border");
		}
		protected function refreshBorderSprite(e:Event=null):void {
			if (isRoot) return;
			graphics.clear();
			if (border==0 || right==0) return;
			var px:Number;
			if (border==1) {
				px=width+Math.floor(app.gutterWidth/2);
			} else {
				px=width-Math.floor(app.colWidth/2);
			}
			graphics.lineStyle(1, 0x000000);
			graphics.moveTo(px, 0);
			graphics.lineTo(px, height);
		}
		public function get top():uint {
			return y/app.boxHeight;
		}
		public function set top(n:uint):void {
			y=n*app.boxHeight;
		}
		public function getSiblings():Array {
			if (!parent is GridBox) return [];
			return (parent as GridBox).getChildSiblings(this);
		}
		public function getSiblingsOnRow():Array {
			if (!(parent is GridBox)) return [];
			return (parent as GridBox).getBoxesOnRow(y).filter(function(element:GridBox, index:int, arr:Array):Boolean {
				return element!=this;
			}, this);
		}
		public function getChildSiblings(box:GridBox):Array {
			return getBoxes().filter(function(element:GridBox, index:int, arr:Array):Boolean {
				return element!=box;
			});
		}
		public function getBoxes():Array {
			var ar:Array=[];
			for (var i:uint=0; i<numChildren; i++) {
				if (getChildAt(i) is GridBox) ar.push(getChildAt(i));
			}
			ar.sort(childSorter);
			return ar;
		}
		protected function childSorter(a:GridBox, b:GridBox):Number {
			if (a.y!=b.y) return a.y<b.y ? -1 : 1;
			return a.x<b.x ? -1 : 1;
		}
		public function childTouchesRight():Boolean {
			return getBoxes().some(function(element:GridBox, index:int, arr:Array):Boolean {
				return element.type==GridBox.DIV && element.right==(border==2 ? 1 : 0);
			});
		}
		public function get cssClasses():String {
			var s:String='';
			// Gestion du clear
			if (isFirstOnRow() && !isFirstChild()) s+='clear';
			// Les non DIV ne gèrent ni prepend, ni append, ni last, ni border/colborder
			if (type!=GridBox.DIV) return StringUtil.trim(s+' '+moreClasses);
			s+=' span-'+getActualSpan();
			// prepend, append et last
			if (prepend>0) s+=' prepend-'+prepend;
			if (append>0) s+=' append-'+append;
			if (last) s+=' last';
			// Gestion de la bordure
			if (acceptsBorder() && border==1) s+=' border';
			else if (acceptsBorder() && border==2) s+=' colborder';
			//
			if (moreClasses.length>0) s+=' '+moreClasses;
			return StringUtil.trim(s);
		}
		public function getHTML():XML {
			XML.ignoreComments=false;
			XML.ignoreProcessingInstructions=false;
			var xml:XML=new XML("<"+type+" />");
			if (acceptsHTMLContent()) {
				// Non breaking space!
				xml.appendChild(htmlContent.length==0 ? "\u00A0" : htmlContent);
			}
			if (cssClasses.length>0) xml.@["class"]=cssClasses;
			/*if (type!=GridBox.HR) {
				xml.@["class"]=cssClasses;
			} else {
				// Gestion des classes supplémentaires
				xml.@["class"]=moreClasses;
			}*/
			if (domID.length>0) xml.@id=domID;
			var boxes:Array=getBoxes();
			for (var i:uint=0; i<boxes.length; i++) {
				var box:GridBox=boxes[i];
				xml.appendChild(box.getHTML());
				// Gestion du commentaire de fermeture de balise
				var did:String=box.domID;
				var com:XML=new XML("<!-- end "+did+" -->");
				if (did!='' && app.commentClosure) xml.appendChild(com);
			}
			return xml;
		}
		public function acceptsHTMLContent():Boolean {
			return getBoxes().length==0 && type!=GridBox.HR;
		}
		public function isParentWide():Boolean {
			return left==0 && right==0;
		}
		public function isFirstOnRow():Boolean {
			var onRow:Array=getSiblingsOnRow();
			for (var i:uint=0; i<onRow.length; i++) {
				if (onRow[i].x<x) return false;
			}
			return true;
		}
		public function isFirstChild():Boolean {
			if (!(parent is GridBox)) return false;
			var meAndMySiblings:Array=(parent as GridBox).getBoxes();
			return meAndMySiblings[0]==this;
		}
		protected function onLayoutChange(e:GridEvent):void {
			// On redéfinit ce qui permet de placer une boite
			left=_oldLeft;
			// Les type qui doivent prendre toute la largeur s'adaptent
			if (type!=GridBox.DIV) span=(parent as GridBox).span;
			// Les autres se redimensionnent
			else refreshSpan();
		}
		protected function updateLabel():void {
			var s:String=type;
			if (domID.length>0) s+=' - id:'+domID;
			if (acceptsHTMLContent() && htmlContent.length>0) s+=' - '+htmlContent.substr(0, 20)+(htmlContent.length>20 ? '...' : '');
			//lbl.htmlText=s;
			lbl.text=s;
		}
		protected function storeHistoryStep(lbl:String):void {
			if (creating) return;
			app.storeHistoryStep(this, lbl);
		}
		//
		// - Export
		//
		public function exportAsObject():Object {
			var o:Object={};
			if (!isRoot) {
				for each (var prop:String in GridBox.exportableProps) {
					o[prop]=this[prop];
				}
			}
			if (selected) o.selected=true;
			o.children=[];
			var boxes:Array=getBoxes();
			for (var i:uint=0; i<boxes.length; i++) {
				o.children.push(boxes[i].exportAsObject());
			}
			return o;
		}
		public function buildFromObject(o:Object, pApp:Boks):void {
			if (!isRoot) {
				for each (var prop:String in GridBox.exportableProps) {
					this[prop]=o[prop];
				}
			}
			if (o.selected) select();
			for (var i:uint=0; i<o.children.length; i++) {
				var curChildO:Object=o.children[i];
				var b:GridBox=new GridBox(pApp);
				b.addEventListener(ResizeEvent.RESIZE, onChildResize);
				b.buildFromObject(curChildO, pApp);
				b.updateHeight();
				addChild(b);
			}
			updateHeight();
		}
	}
}