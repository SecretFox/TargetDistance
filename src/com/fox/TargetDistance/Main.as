import com.Utils.Archive;
import com.fox.TargetDistance.Icon;

class com.fox.TargetDistance.Main
{
	private static var s_app:Icon;

	public static function main(swfRoot:MovieClip):Void
	{
		s_app = new Icon(swfRoot);
		swfRoot.OnModuleActivated = OnActivated;
		swfRoot.OnModuleDeactivated = OnDeactivated;
	}

	public function Main() { }

	public static function OnActivated(config: Archive):Void
	{
		s_app.Activate(config);
	}

	public static function OnDeactivated():Archive
	{
		return s_app.Deactivate();
	}
}