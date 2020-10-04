package djTui.win;

import djTui.BaseElement;
import djTui.el.Button;

/**
 * A Table/grid of buttons where you can select between them using the arrow keys
 * --
 * - Multiple columns
 * - Primarily used for adding buttons, but you can add anything else with put();
 * - add() to add content
 * - getData() to get current cursor position
 * - setButtonStyle() to customize buttons
 * - setColumnStyle() to customize padding and separator
 */
class ButtonGrid extends Window
{

	// The relative X position (from window 0,0) of columns start position
	// DEV: You can adjust the positioning of columns after size();
	public var col_pos:Array<Int>;

	// Which elements go in which column. Store all buttons here
	var col_el:Array<Array<BaseElement>>;

	// Number of columns
	var col_count:Int;

	// Cursor position. Stores Indexes. Starts at (0,0)
	var c_x:Int;
	var c_y:Int;

	// Vertical Pad betwen elements
	var pad_el:Int = 0;

	// If true, will loop on the edges
	public var flag_loop:Bool = false;

	// - Global Button Styles for All Buttons
	var btn_style:Int = 0;		// Index. Check `Button.hx` button style symbols
	var btn_width:Int = 0;		// Force Button width
	var btn_padOut:Int = 0;		// Symbol Pad Outer
	var btn_padIn:Int = 0;		// Symbol Pad Inner

	// - Drawable separator
	var sep_enable:Bool = false;
	var sep_symbol:String;

	// - Maps <SID> to <CURSORPOS> of all elements
	//  CURSORPOS : `x,y` starting at 0,0 for top left
	var posMap:Map<String,String>;

	/* Optional, if set will trigger when a button is pressed
	 * callback(SID, POS) - SID is the element sid,
	 * POS is the position of the element in the grid, starting at (0,0) top left */
	public var onPush:Button->String->Void;

	/**
	   @param	_w Width -
	   @param	_h Height -
	   @param	columns How many columns
	**/
	public function new(?_sid:String, _w:Int = 20, _h:Int = 10, columns:Int = 2)
	{
		col_pos = [];
		col_el = [];
		c_x = 0; c_y = 0;
		col_count = columns;
		posMap = new Map();

		super(_sid, _w, _h); // Keep it last
	}//---------------------------------------------------;

	/**
	   Sets button display mode
	   ~ Call this before adding elements
	   @param	buttonStyle Common button style for all buttons? (0-4)
	   @param	buttonWidth 0 for auto, other for forced width
	   @param	padOut Symbol pad Outer
	   @param	padIn Symbol pad Inner
	**/
	public function setButtonStyle(buttonStyle:Int, buttonWidth:Int, padOut:Int, padIn:Int):ButtonGrid
	{
		btn_style = buttonStyle;
		btn_width = buttonWidth;
		btn_padOut = padOut;
		btn_padIn = padIn;
		return this;
	}//---------------------------------------------------;


	/**
	   Set a separator style for the columns and a padding
	   NOTE: the separator color is `style.text`. This is if you want a different color than the border
	   @param	sep  Separator symbol Index. -1 for none. 0 to follow border style. Else to apply border ID style
	   @param	Xpad  Left Edge Padding
	   @param	Vpad  Vertical padding between elements
	**/
	public function setColumnStyle(sep:Int = -1, Xpad:Int = 1, Vpad:Int = 0)
	{
		pad_el = Vpad;
		padX = Xpad;

		// -
		if (sep >-1)
		{
			sep_enable = true;
			if (sep == 0)
			{
				if (borderStyle > 0) sep = borderStyle; else sep = 1;
			}
			sep_symbol = Styles.border[sep].charAt(7);

			// Need to have a padding
			if (padX == 0) padX = 1;
		}

		setupColumns(); // Because paddingX might have changed
	}//---------------------------------------------------;

	override public function size(_w:Int, _h:Int):BaseElement
	{
		super.size(_w, _h);
		setupColumns();
		return this;
	}//---------------------------------------------------;

	/**
	   Calculate column sizes
	**/
	function setupColumns()
	{
		var colWidth:Int = Math.floor(width / col_count);
		for (i in 0...col_count) col_pos[i] = colWidth * i;
	}//---------------------------------------------------;


	/**
	   Quickly add a button at a column. Conforms to global button style
	   @param	col The column to add the button to ( start at 0 )
	   @param	name Display name
	   @param	_sid If you don't set a unique ID, it will be autogenerated
					with "x,y" position on the grid, starting at (0:0)
	**/
	public function add(col:Int, text:String, ?_sid:String):Button
	{
		var b = new Button(_sid, text, btn_style, btn_width);
			b.focus_lock = true;

		if (btn_style > 0)
		{
			b.setSideSymbolPad(btn_padOut, btn_padIn);
		}

		putEl(col, b);

		posMap.set(b.SID, '${col},' + (rowsAt(col) - 1)); // 'x,y' of the new button

		return b;
	}//---------------------------------------------------;


	/**
	   Appends an element at target column.
	   @param	col The column to append to ( start at 0 )
	   @param	el The element
	**/
	public function putEl(col:Int, el:BaseElement)
	{
		var xx = x + col_pos[col] + padX;
		var yy = y + padY;

		if (col_el[col] == null)
		{
			col_el[col] = [];
		}else
		{
			yy = col_el[col][rowsAt(col) - 1].y + 1 + pad_el;
		}

		el.pos(xx, yy);
		addChild(el);
		col_el[col].push(el);
	}//---------------------------------------------------;


	/**
	   (Autocalled) in cases like [TAB] key was pressed
	**/
	override function focusNext(loop:Bool = false)
	{
		if (super.focusNext(loop))
		{
			// Re-adjust the Cursor Location to the new active element
			var pp = posMap.get(active.SID).split(',');
			c_x = Std.parseInt(pp[0]);
			c_y = Std.parseInt(pp[1]);
			return true;
		}

		return false;
	}//---------------------------------------------------;

	override function onKey(key:String)
	{
		// Note: The generic handler will not process UP/DOWN, since the element is locked
		super.onKey(key);

		switch(key)
		{
			case "up": 	 focusRelY(-1);
			case "down": focusRelY(1);
			case "left": focusRelX(-1);
			case "right":focusRelX(1);
			default:
		}
	}//---------------------------------------------------;

	// Focus relative to cursor at Y axis,
	// Will automatically loop if flag is set
	function focusRelY(dir:Int)
	{
		if (col_el[c_x][c_y + dir] == null)
		{
			if (flag_loop) {
				if (c_y + dir < 0) c_y = rowsAt(c_x) - 1; else c_y = 0;
			}else return;

		}else
		{
			c_y += dir;
		}

		col_el[c_x][c_y].focus();

	}//---------------------------------------------------;

	// Focus relative to cursor at X axis,
	// Will automatically loop if flag is set
	function focusRelX(dir:Int)
	{
		if (col_el[c_x + dir] == null)
		{
			if (flag_loop) {
				if (c_x + dir < 0) c_x = col_count - 1; else c_x = 0;
			}else return;
		}else
		{
			c_x += dir;
		}

		// Check if the next column has a valid same row
		// If not focus the last element
		// DEV: Should never be <0. You need to add at least one element at each row
		if (col_el[c_x][c_y] == null)
		{
			c_y = rowsAt(c_x) - 1;
		}

		col_el[c_x][c_y].focus();
	}//---------------------------------------------------;

	// -- helper
	function rowsAt(col:Int)
	{
		return col_el[col].length;
	}//---------------------------------------------------;

	/**
	   Return the current Cursor Posion in "x,y" format
	   Starts at (0,0) for top-left
	**/
	public function getCursorPos():String
	{
		return c_x + ',' + c_y;
	}//---------------------------------------------------;

	override function onElementCallback(st:String, el:BaseElement)
	{
		super.onElementCallback(st, el);

		if (st == "fire")
		{
			Tools.tCall(onPush, cast el, posMap.get(el.SID));
		}
	}//---------------------------------------------------;

	// Adjust pointer location
	override public function focus()
	{
		if (!flag_return_focus_once || active_last == null)
		{
			c_x = 0;
			c_y = 0;
		}
		super.focus();
	}//---------------------------------------------------;

	//
	override public function draw():Void
	{
		super.draw();
		if (sep_enable)
		{
			_readyCol(); // <-- draw separator with BG,FG
			for (i in 1...col_count)
			{
				WM.D.lineV(x + col_pos[i], y + padY, height - (padY * 2), sep_symbol);
			}
		}
	}//---------------------------------------------------;

}// --