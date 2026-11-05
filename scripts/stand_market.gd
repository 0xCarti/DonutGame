extends Control
## A ticket-booth catalog shared by desktop and touch. It never grants items.
signal purchase_requested(id: String)
signal equip_requested(id: String)
signal preview_requested(id: String)
signal buff_requested(id: String)
signal buff_cleared
signal page_requested(category: String, page: int)
signal closed

const INK = Color("10252b")
const CREAM = Color("fff1d2")
const GOLD = Color("ffc76f")
const MINT = Color("a4e1c1")
const MUTED = Color("a6bdb8")
const PANEL = Color("19343a")
const CATEGORIES = ["sets", "operator", "counter", "celebration", "buffs"]
const TITLES = ["Stand styles", "Operator", "Counter", "Celebrations", "Shift supplies"]
var catalog: Array = []
var balance = 0
var can_queue = false
var pending_buff = ""
var category = "sets"
var page = 0
var status_text = ""

class TicketArt extends Control:
	var tint = Color("ffc76f")
	var kind = "sets"
	func _draw() -> void:
		draw_style_box(_paper(), Rect2(Vector2.ZERO, size))
		for x in range(12, int(size.x), 16):
			draw_line(Vector2(x, 11), Vector2(x + 7, 11), Color(tint, .38), 2)
			draw_line(Vector2(x, size.y - 11), Vector2(x + 7, size.y - 11), Color(tint, .38), 2)
		var c = size * .5
		if kind == "buffs":
			draw_colored_polygon(PackedVector2Array([c+Vector2(4,-29),c+Vector2(-21,5),c+Vector2(-3,5),c+Vector2(-8,29),c+Vector2(24,-8),c+Vector2(6,-8)]), tint)
		elif kind == "celebration":
			for i in range(12):
				var d = Vector2.from_angle(i * TAU / 12)
				draw_line(c+d*13,c+d*30,tint,4,true)
			draw_circle(c,7,CREAM)
		else:
			draw_circle(c,30,tint,true,-1,true)
			draw_circle(c,5,INK,true,-1,true)
			for i in range(7):
				var p = c + Vector2.from_angle(i*TAU/7+.1)*21
				draw_line(p-Vector2(2,2),p+Vector2(3,1),CREAM,3,true)
			draw_line(c-Vector2(93,0),c-Vector2(50,0),Color(tint,.6),2)
			draw_line(c+Vector2(50,0),c+Vector2(93,0),Color(tint,.6),2)
	func _paper() -> StyleBoxFlat:
		var style = StyleBoxFlat.new()
		style.bg_color = INK.lightened(.04)
		style.border_color = tint
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		return style

func _ready() -> void:
	size = Vector2(1220, 740)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _category_of(item: Dictionary) -> String:
	var slot = str(item.get("slot", ""))
	if str(item.id) in ["fresh_oil", "freshly_serviced", "good_vibes", "emergency_batter", "rush_contract"]: return "buffs"
	if slot.begins_with("operator"): return "operator"
	if slot.begins_with("counter"): return "counter"
	if slot == "celebration": return "celebration"
	return "sets"

func _build() -> void:
	_label(self, "THE TICKET BOOTH", Vector2(28,18), Vector2(860,28),22,GOLD)
	_label(self, "Make this little stand yours.", Vector2(26,52),Vector2(850,51),37,CREAM)
	_label(self, "%d TICKETS" % balance,Vector2(898,26),Vector2(294,44),28,MINT).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_label(self,"Earn Tickets by clearing shifts and collecting badges.",Vector2(28,104),Vector2(1158,28),22,MUTED)
	for i in range(CATEGORIES.size()):
		var tab = _button(self,TITLES[i],Vector2(28+i*234,136),Vector2(222,80),func(): page_requested.emit(CATEGORIES[i],0),GOLD if category==CATEGORIES[i] else PANEL)
		tab.name = "Tab_"+CATEGORIES[i]
	var filtered: Array = []
	for item in catalog:
		if _category_of(item)==category: filtered.append(item)
	var pages = maxi(1,int(ceil(filtered.size()/3.0)))
	page = clampi(page,0,pages-1)
	for col in range(3):
		var index = page*3+col
		if index>=filtered.size(): break
		_build_card(filtered[index],col)
	var message = "One buff per shift. Select it between shifts; it is used when the next shift opens." if category=="buffs" else "Preview every look on your own counter. Cosmetic items never change your stats."
	if not pending_buff.is_empty(): message = "NEXT SHIFT: " + pending_buff.replace("_"," ").capitalize() + " · one supply equipped"
	_label(self,message if status_text.is_empty() else status_text,Vector2(28,578),Vector2(1164,64),22,MINT).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(self,"‹ PREVIOUS",Vector2(28,642),Vector2(214,80),func(): page_requested.emit(category,page-1),PANEL).disabled=page==0
	_label(self,"%d / %d" %[page+1,pages],Vector2(250,666),Vector2(112,36),22,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_button(self,"NEXT ›",Vector2(370,642),Vector2(214,80),func(): page_requested.emit(category,page+1),PANEL).disabled=page==pages-1
	if category == "buffs" and not pending_buff.is_empty():
		_button(self,"UNQUEUE SUPPLY",Vector2(610,642),Vector2(312,80),func(): buff_cleared.emit(),PANEL)
	else:
		_label(self,"Real-money checkout unavailable",Vector2(610,661),Vector2(312,50),20,MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(self,"BACK",Vector2(950,642),Vector2(242,80),func(): closed.emit(),GOLD)

func _build_card(item: Dictionary, col: int) -> void:
	var card = Panel.new()
	card.position=Vector2(28+col*394,224)
	card.size=Vector2(376,338)
	card.add_theme_stylebox_override("panel",_style(PANEL))
	add_child(card)
	var id = str(item.id)
	var tint = Color("f6c773")
	if id.begins_with("neon"): tint=Color("86e8e2")
	elif id.begins_with("grandmas"): tint=Color("efadbb")
	elif id.begins_with("chrome"): tint=Color("c8dce0")
	var art = TicketArt.new()
	art.position=Vector2(16,14)
	art.size=Vector2(344,62)
	art.tint=tint
	art.kind=category
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	_label(card,str(item.get("name",id)),Vector2(16,88),Vector2(344,62),25,CREAM)
	var description = _label(card,str(item.get("description","")),Vector2(16,158),Vector2(344,76),21,MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var cost = int(item.get("ticket_cost",item.get("cost",0)))
	var owned = bool(item.get("owned",false))
	var equipped = bool(item.get("equipped",false))
	if category=="buffs":
		var count = int(item.get("count",0))
		var buy = _button(card,"%d TICKETS" % cost,Vector2(16,244),Vector2(166,80),func(): purchase_requested.emit(id),GOLD)
		buy.disabled=balance<cost
		var use = _button(card,"QUEUE (%d)" % count,Vector2(194,244),Vector2(166,80),func(): buff_requested.emit(id),MINT)
		use.disabled=not can_queue or count<=0 or not pending_buff.is_empty()
	else:
		_button(card,"PREVIEW",Vector2(16,244),Vector2(138,80),func(): preview_requested.emit(id),PANEL)
		var caption = "EQUIPPED" if equipped else "EQUIP" if owned else "%d TICKETS" % cost
		var button = _button(card,caption,Vector2(166,244),Vector2(194,80),func():
			if owned: equip_requested.emit(id)
			else: purchase_requested.emit(id),MINT if owned else GOLD)
		button.disabled=equipped or (not owned and balance<cost)

func _style(color:Color)->StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(9)
	style.set_border_width_all(1)
	style.border_color=color.lightened(.18)
	return style

func _label(parent:Node,value:String,at:Vector2,dimensions:Vector2,font_size:int,color:Color)->Label:
	var label=Label.new()
	# Configure text constraints before assigning content. Otherwise Label can
	# retain its initial unwrapped minimum width even after clipping is enabled.
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.clip_text=true
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	label.text=value
	label.position=at
	label.size=dimensions
	return label

func _button(parent:Node,value:String,at:Vector2,dimensions:Vector2,callback:Callable,color:Color)->Button:
	var button=Button.new()
	button.text=value
	button.position=at
	button.size=dimensions
	button.add_theme_font_size_override("font_size",24)
	button.add_theme_color_override("font_color",INK if color in [GOLD,MINT] else CREAM)
	button.add_theme_color_override("font_hover_color",INK if color in [GOLD,MINT] else CREAM)
	button.add_theme_stylebox_override("normal",_style(color))
	button.add_theme_stylebox_override("hover",_style(color.lightened(.12)))
	button.add_theme_stylebox_override("pressed",_style(color.darkened(.1)))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
