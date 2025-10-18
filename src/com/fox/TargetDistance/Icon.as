import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.Shortcut;
import com.Utils.Archive;
import com.Utils.Draw;
import com.Utils.ID32;
import com.fox.Utils.Common;
import flash.filters.DropShadowFilter;
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

	private var m_trackAbilities:DistributedValue;
	private var m_Sticky:DistributedValue;

	private var m_Target:Character
	private var updateInterval:Number;
	private var m_Player:Character
	public var m_Config:Archive;

	public function Icon(swfRoot: MovieClip)
	{
		m_swfRoot = swfRoot;
		m_Player = Character.GetClientCharacter();
		Shortcut.SignalShortcutRangeEnabled.Connect( SlotShortcutRangeEnabled, this );
		m_trackAbilities = DistributedValue.Create("TargetDistance_TrackAbilities");
		m_Sticky = DistributedValue.Create("TargetDistance_Sticky");
		m_trackAbilities.SignalChanged.Connect(SlotTrackAbilities, this);
	}

	private function SlotShortcutRangeEnabled(s, v, buffered)
	{
		if (!buffered)
		{
			setTimeout(Delegate.create(this, SlotShortcutRangeEnabled), 5, s, v, true);
			return;
		}
		var maxCount = 6;
		if (m_trackAbilities.GetValue())
		{
			var foundCount = 0;
			var rangeAbilities = 0;
			for (var i in _root.abilitybar.m_AbilitySlots)
			{
				var slot = _root.abilitybar.m_AbilitySlots[i];
				var flag = slot["m_Ability"]["m_Flags"];
				if (flag & 0x1/* || flag & 0x8*/)
					foundCount += 1;
			}
			var color = foundCount == 0 ? 0xFFFFFF : foundCount != maxCount ? 0xF27209 : 0xFB0000;
			if (m_Target)
			{
				format.color = color;
				m_DistanceText.setTextFormat(format);
				m_DistanceText.setNewTextFormat(format);
			}
		}
	}

	private function onMouseWheel(delta:Number):Void
	{
		if (Mouse.getTopMostEntity() == m_TargetDistanceIcon)
		{
			var scale = m_TargetDistanceIcon._xscale + delta * 5;
			scale = Math.min(Math.max(10, scale), 500);
			m_TargetDistanceIcon._xscale = m_TargetDistanceIcon._yscale = scale;
			m_Config.ReplaceEntry("Scale", scale);
		}
	}

	private function GuiEdit(state:Boolean)
	{
		if (state)
		{
			Mouse.addListener(this);
			m_Player.SignalOffensiveTargetChanged.Disconnect(UpdateTarget, this);
			clearInterval(updateInterval);
			m_TargetDistanceIcon._visible = true;
			m_DistanceText.text = "00.0m";
			m_TargetDistanceIcon.onPress = Delegate.create(this,function ()
			{
				this.m_TargetDistanceIcon.startDrag();
			});
			m_TargetDistanceIcon.onRelease = Delegate.create(this,function ()
			{
				this.m_TargetDistanceIcon.stopDrag();
				this.UpdatePosition()
			});
			m_TargetDistanceIcon.onReleaseOutside = Delegate.create(this,function ()
			{
				this.m_TargetDistanceIcon.stopDrag();
				this.UpdatePosition()
			});
			m_TargetDistanceIcon.onPressAux = Delegate.create(this, function()
			{
				var alpha = this.m_BGClip._alpha + 10;
				if (alpha > 100) alpha = 0;
				this.m_BGClip._alpha = alpha;
				this.m_Config.ReplaceEntry("Alpha", alpha);
			});
		}
		else
		{
			if (m_Target)
			{
				clearInterval(updateInterval);
				updateInterval = setInterval(Delegate.create(this, UpdateDistance), 50);
			}
			else
			{
				m_TargetDistanceIcon._visible = false;
			}
			Mouse.removeListener(this);
			if (!m_Player.SignalOffensiveTargetChanged.IsSlotConnected(UpdateTarget, this))
			{
				m_Player.SignalOffensiveTargetChanged.Connect(UpdateTarget, this);
			}
			
			m_TargetDistanceIcon.stopDrag();
			m_TargetDistanceIcon.onPress = 
				m_TargetDistanceIcon.onRelease = 
				m_TargetDistanceIcon.onReleaseOutside =
				m_TargetDistanceIcon.onPressAux = 
				undefined;
		}
	}

	private function SlotTrackAbilities()
	{
		if (!m_trackAbilities.GetValue())
		{
			format.color = 0xFFFFFF;
			m_DistanceText.setTextFormat(format);
			m_DistanceText.setNewTextFormat(format);
		}
	}

	public function Activate(config:Archive):Void
	{
		m_Config = config;
		if (!m_TargetDistanceIcon)
		{
			CreateDistanceClip();
		}
	}

	public function Deactivate()
	{
		return m_Config;
	}
	
	private function UpdateTarget(id:ID32)
	{
		if (!id.IsNull())
		{
			if ( m_Target && m_Target.GetID().Equal(id)) return;
			clearInterval(updateInterval);
			if (m_Target)
			{
				m_Target.SignalCharacterDestructed.Disconnect(SlotCharacterDestructed, this);
			}
			m_Target = Character.GetCharacter(id);
			updateInterval = setInterval(Delegate.create(this, UpdateDistance), 50);
			m_TargetDistanceIcon._visible = true;
			m_Target.SignalCharacterDestructed.Connect(SlotCharacterDestructed, this);
		}
		else if(!m_Sticky.GetValue())
		{
			clearInterval(updateInterval);
			m_TargetDistanceIcon._visible = false;
			m_Target.SignalCharacterDestructed.Disconnect(SlotCharacterDestructed, this);
			m_Target = undefined;
		}
		if ( m_Target)
		{
			SlotShortcutRangeEnabled();
		}
	}
	
	public function SlotCharacterDestructed():Void 
	{
		clearInterval(updateInterval);
		m_TargetDistanceIcon._visible = false;
		m_Target.SignalCharacterDestructed.Disconnect(SlotCharacterDestructed, this);
		m_Target = undefined;
	}
	
	public function round(num)
	{
		return Math.round(num * 10) / 10
	}

	private function UpdateDistance()
	{
		var m_distance = round(m_Target.GetDistanceToPlayer());
		if (m_distance % 1 == 0) m_distance = string(m_distance) + ".0";
		m_DistanceText.text = string(m_distance) + "m";
	}

	private function UpdatePosition():Void
	{
		var pos = Common.getOnScreen(m_TargetDistanceIcon);
		m_TargetDistanceIcon._x = pos.x;
		m_TargetDistanceIcon._y = pos.y;
		m_Config.ReplaceEntry("Pos", pos);
	}

	public function CreateDistanceClip():Void
	{
		var pos = m_Config.FindEntry("Pos", new Point(550, 100));
		var Scale = m_Config.FindEntry("Scale", 100);
		var Alpha = m_Config.FindEntry("Alpha", 100);
		m_TargetDistanceIcon = m_swfRoot.createEmptyMovieClip("m_TargetDistanceIcon", m_swfRoot.getNextHighestDepth());
		m_TargetDistanceIcon._x = pos.x;
		m_TargetDistanceIcon._y = pos.y;
		format = new TextFormat("_StandardFont", 14, 0xFFFFFF, true, false, false, undefined, undefined, "center");
		m_BGClip = m_TargetDistanceIcon.createEmptyMovieClip("BG", m_TargetDistanceIcon.getNextHighestDepth());
		
		m_DistanceText = m_TargetDistanceIcon.createTextField("m_DistanceText", m_TargetDistanceIcon.getNextHighestDepth(), 3, 3, 45, 18);
		m_DistanceText.filters = [new DropShadowFilter(20, 45, 0, 1, 0, 0, 107, 2, false, false, false)];
		m_DistanceText.setNewTextFormat(format);
		m_DistanceText.setTextFormat(format);
		m_DistanceText.selectable = false;
		m_DistanceText.embedFonts = true;
		m_DistanceText.autoFit = true;
		m_DistanceText.autoSize = "center";
		m_TargetDistanceIcon._xscale = m_TargetDistanceIcon._yscale = Scale;
		
		m_DistanceText.text = "00.0m";

		Draw.DrawRectangle(m_BGClip, 0, 0, m_DistanceText._width + 6, m_DistanceText._height + 6, 0x000000, 100, [4, 4, 4, 4]);
		m_BGClip._alpha = Alpha;
		m_DistanceText.text = "";
		
		GuiEdit(false);
		GlobalSignal.SignalSetGUIEditMode.Connect(GuiEdit, this);
		m_TargetDistanceIcon._visible = false;
		UpdateTarget(m_Player.GetOffensiveTarget());
	}
}