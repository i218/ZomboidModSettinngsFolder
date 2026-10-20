import java.nio.file.*;
/** Installed game's Lua VM; no native UI, game world or user settings are opened. */
public final class KahluaCheck {
 public static void main(String[] files)throws Exception {
  var p=new se.krka.kahlua.j2se.J2SEPlatform();var globals=p.newTable();globals.rawset("_G",globals);
  globals.rawset("unicodeName", "\u0418\u043d\u0442\u0435\u0440\u0444\u0435\u0439\u0441");
  globals.rawset("searchName", "\u0418\u043d\u0422\u0435\u0420\u0444\u0415\u0439\u0421 [Special]");
  globals.rawset("searchNeedle", "\u0438\u043d\u0442\u0435\u0440\u0444\u0435\u0439\u0441");
  se.krka.kahlua.stdlib.BaseLib.register(globals);
  se.krka.kahlua.stdlib.BaseLib.setPrintCallback(System.out::println);
  se.krka.kahlua.stdlib.StringLib.register(p,globals);se.krka.kahlua.stdlib.TableLib.register(p,globals);
  se.krka.kahlua.j2se.MathLib.register(p,globals);se.krka.kahlua.stdlib.CoroutineLib.register(p,globals);
  var t=new se.krka.kahlua.vm.KahluaThread(p,globals);t.debugOwnerThread=Thread.currentThread();
  for(String file:files){var closure=se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(Files.readString(Path.of(file)),file,globals);
   Object[] result=t.pcall(closure,new Object[0]);if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(file+": "+java.util.Arrays.toString(result));
  }
  System.out.println("PASS installed Kahlua; stock registry and form builder exercised with UI/file doubles; live GUI untested");
 }
}
