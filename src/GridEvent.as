package {
	import flash.events.Event;
	public class GridEvent extends Event {
		public static const BOX_HEIGHT_CHANGED:String='boxHeightChanged';
		public static const LAYOUT_CHANGE:String='layoutChange';
		public static const UNSELECT:String='unselect';
		public static const SELECT:String='select';
		public static const MOVE:String='move';
		public static const RESIZE:String='resize';
		public static const ROOT_CHILD_CHANGE:String='rootChildChange';
		public var data:*;
		public function GridEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);
		}
	}
}