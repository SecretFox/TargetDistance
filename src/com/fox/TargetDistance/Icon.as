import com.GameInterface.Chat;
import com.GameInterface.DistributedValue;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.Game.Shortcut;
import com.Utils.Archive;
import com.Utils.ID32;
import com.fox.Utils.Common;
import flash.geom.Point;
import mx.utils.Delegate;
import com.Utils.GlobalSignal;

class com.fox.TargetDistance.Icon
{
	private var m_swfRoot: MovieClip;
	private var m_TargetDistanceIcon:MovieClip;
	private var m_DistanceText:TextField;
	private var m_Icon:MovieClip;
	private var m_BGClip:MovieClip;
	private var format:TextFormat;
	
	private var m_trackDistance:DistributedValue;
	private var m_pos:Point;
	private var m_fontSize:Number;
	private var m_BGAlpha:Number;

	private var m_Target:CharacterBase
	private var m_Mouselistener:Object
	private var update;
	private var m_Player:CharacterBase
	private var m_AbilitySlots:Array = new Array();
	
	public function Icon(swfRoot: MovieClip)
	{
		m_swfRoot = swfRoot
		m_Player = new CharacterBase(CharacterBase.GetClientCharID());
		m_Player.SignalOffensiveTargetChanged.Connect(UpdateTarget, this);
		Shortcut.SignalShortcutRangeEnabled.Connect( SlotShortcutRangeEnabled, this );
		m_Mouselistener = new Object();
		m_Mouselistener.onMouseWheel = Delegate.create(this, MouseWheelEventHandler);
	}
	
	private function SlotShortcutRangeEnabled(){
		if (m_trackDistance.GetValue()){
			var foundCount = 0;
			for (var i in _root.abilitybar_2_.m_AbilitySlots)
			{
				var slot = _root.abilitybar_2_.m_AbilitySlots[i];
				var flag = slot["m_Ability"]["m_Flags"]
				foundCount += flag & 0x1;
			}
			var color = foundCount == 0 ? 0xFFFFFF : foundCount != 6 ? 0xF27209 : 0xFB0000;
			if (!m_Player.GetOffensiveTarget().IsNull()){
				format.color = color;
				m_DistanceText.setTextFormat(format);
				m_DistanceText.setNewTextFormat(format);
			}
		}
	}

	private function MouseWheelEventHandler(delta:Number):Void {
		if (Mouse.getTopMostEntity() == m_TargetDistanceIcon) {
			if (delta < 0) {
				var tar = format.size-1;
				if(tar>10){
					format.size = tar;
					m_DistanceText.setNewTextFormat(format);
					m_DistanceText.setTextFormat(format);
					m_fontSize = tar;
				}
			}
			else {
				var tar = format.size+1;
				if(tar<70){
					format.size = tar;
					m_DistanceText.setNewTextFormat(format);
					m_DistanceText.setTextFormat(format);
					m_fontSize = tar;
				}
			}
		}
	}
	
	private function GuiEdit(state:Boolean)
	{
		if (state)
		{
			Mouse.addListener(m_Mouselistener);
			m_Player.SignalOffensiveTargetChanged.Disconnect(UpdateTarget, this);
			clearInterval(update);
			m_TargetDistanceIcon._visible = true;
			m_DistanceText.text = "X.Xm"
			m_TargetDistanceIcon.onPress = Delegate.create(this,function ()
			{
				this.m_TargetDistanceIcon.startDrag();
			});
			m_TargetDistanceIcon.onRelease = Delegate.create(this,function ()
			{
				this.m_TargetDistanceIcon.stopDrag();
				this.UpdateIconPosition()
			});
			m_TargetDistanceIcon.onReleaseOutside = Delegate.create(this,function ()
			{
				this.m_TargetDistanceIcon.stopDrag();
				this.UpdateIconPosition()
			});
		}
		else
		{
			Mouse.removeListener(m_Mouselistener);
			m_Player.SignalOffensiveTargetChanged.Connect(UpdateTarget, this);
			m_TargetDistanceIcon._visible = false;
			m_TargetDistanceIcon.stopDrag();
			m_TargetDistanceIcon.onPress = Delegate.create(this, function(){
				this.m_trackDistance.SetValue(!this.m_trackDistance.GetValue());
				(this.m_trackDistance.GetValue())?Chat.SignalShowFIFOMessage.Emit("Tracking abilities",0):Chat.SignalShowFIFOMessage.Emit("Untracking abilities",0);
			});
			m_TargetDistanceIcon.onPressAux = Delegate.create(this, function(){
				var alpha = this.m_BGAlpha + 10;
				if (alpha > 100) alpha = 0;
				this.m_BGClip._alpha = alpha;
				this.m_BGAlpha = alpha;
			});	
			m_TargetDistanceIcon.onRelease = undefined;
			m_TargetDistanceIcon.onReleaseOutside = undefined;
			UpdateIconPosition();
		}
	}
	
	private function ChangeBG(){
		if (!m_trackDistance.GetValue()){
			format.color = 0xFFFFFF;
			m_DistanceText.setTextFormat(format);
			m_DistanceText.setNewTextFormat(format);
		}
	}

	public function Activate(config:Archive):Void
	{
		m_pos = Point(config.FindEntry("CoordPos", new Point(550, 100)));
		m_fontSize = Number(config.FindEntry("fontSize", 14));
		m_swfRoot.onEnterFrame = Delegate.create(this, onframe);
		m_trackDistance = DistributedValue.Create("TrackDistance_Track");
		m_trackDistance.SetValue(Boolean(config.FindEntry("Track", true)));
		m_BGAlpha = Number(config.FindEntry("BGAlpha", 100));
		m_AbilitySlots = new Array();
		m_AbilitySlots.push(true, true, true, true, true);
		m_trackDistance.SignalChanged.Connect(ChangeBG, this);
	}

	public function Deactivate()
	{
		var config:Archive = new Archive();
		config.AddEntry("CoordPos", m_pos);
		config.AddEntry("fontSize", m_fontSize);
		config.AddEntry("Track", m_trackDistance.GetValue());
		config.AddEntry("BGAlpha",m_BGAlpha);
		clearInterval(update);
		return config
	}

	private function onframe():Void
	{
		m_swfRoot.onEnterFrame = undefined;
		if (m_swfRoot.TopIcon == undefined)
		{
			CreateTopIcon();
		}
	}
	
	
	private function UpdateTarget(id:ID32){
		if (!id.IsNull()){
			m_Target = new CharacterBase(id);
			update = setInterval(Delegate.create(this, UpdateDistance), 50);
			m_TargetDistanceIcon._visible = true;
		}
		else{
			clearInterval(update);
			m_TargetDistanceIcon._visible = false;
			m_AbilitySlots = new Array();
			m_AbilitySlots.push(true, true, true, true, true);
		}
	}
	
	private function UpdateDistance(){
		var m_distance = Math.round(m_Target.GetDistanceToPlayer() * 10) / 10
		if (m_distance % 1 == 0) m_distance = string(m_distance) + ".0";
		m_DistanceText.text = string(m_distance) + "m";
		m_BGClip._width = m_DistanceText._width;
		m_BGClip._height = m_DistanceText._height;
	}

	private function UpdateIconPosition():Void
	{
		m_pos = Common.getOnScreen(m_TargetDistanceIcon);
		m_pos = Common.getOnScreen(m_TargetDistanceIcon);
		m_TargetDistanceIcon._x = m_pos.x;
		m_TargetDistanceIcon._y = m_pos.y;
	}
	
	public function CreateTopIcon():Void
	{
		m_TargetDistanceIcon = m_swfRoot.createEmptyMovieClip("TopIcon", m_swfRoot.getNextHighestDepth());
		m_TargetDistanceIcon._x = m_pos.x;
		m_TargetDistanceIcon._y = m_pos.y;
		format = new TextFormat("src.assets.fonts.FuturaMD_BT.ttf", m_fontSize, 0xFFFFFF, true);
		m_BGClip = m_TargetDistanceIcon.createEmptyMovieClip("BG", m_TargetDistanceIcon.getNextHighestDepth());
		m_DistanceText = m_TargetDistanceIcon.createTextField("m_DistanceText",m_TargetDistanceIcon.getNextHighestDepth(),0, 0, 0, 0);

		m_DistanceText.selectable = false;
		m_DistanceText.embedFonts = true;
		m_DistanceText.autoSize = true;
		m_DistanceText.setNewTextFormat(format);
		m_DistanceText.setTextFormat(format);
		
		m_BGClip.beginFill(0x000000, 100);
		m_BGClip.moveTo(0, 0)
		m_BGClip.lineTo(2, 0);
		m_BGClip.lineTo(2, 2);
		m_BGClip.lineTo(0, 2);
		m_BGClip.lineTo(0, 0);
		m_BGClip.endFill();
		m_BGClip._alpha = m_BGAlpha;
		
		

		m_TargetDistanceIcon.onPress = Delegate.create(this, function(){
			this.m_trackDistance.SetValue(!this.m_trackDistance.GetValue());
			(this.m_trackDistance.GetValue())?Chat.SignalShowFIFOMessage.Emit("Tracking abilities",0):Chat.SignalShowFIFOMessage.Emit("Untracking abilities",0);
		});
		m_TargetDistanceIcon.onPressAux = Delegate.create(this, function(){
			var alpha = this.m_BGAlpha + 10;
			if (alpha > 100) alpha = 0;
			this.m_BGClip._alpha = alpha;
			this.m_BGAlpha = alpha;
		});	
		GlobalSignal.SignalSetGUIEditMode.Connect(GuiEdit, this);
		m_TargetDistanceIcon._visible = false;
	}
}