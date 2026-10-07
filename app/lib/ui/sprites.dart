import 'package:flutter/widgets.dart';

/// Sprites de l'habillage matériel (générés par IA depuis docs/design/assets,
/// détourés en PNG alpha dans assets/ui/). Les états dynamiques — enfoncement,
/// halos, chiffres, couleurs de diodes — restent dessinés par le code ; les
/// sprites ne portent que la matière.
abstract final class VjSprites {
  static const fxBtn = AssetImage('assets/ui/fx_btn.png');
  static const fxBtnLit = AssetImage('assets/ui/fx_btn_lit.png');
  static const fxBtnPressed = AssetImage('assets/ui/fx_btn_pressed.png');
  static const keyUp = AssetImage('assets/ui/key_up.png');
  static const keyDown = AssetImage('assets/ui/key_down.png');
  static const knob = AssetImage('assets/ui/knob.png');
  static const faderRail = AssetImage('assets/ui/fader_rail.png');
  static const faderCap = AssetImage('assets/ui/fader_cap.png');
  static const nixieOff = AssetImage('assets/ui/nixie_off.png');
  static const nixieOn = AssetImage('assets/ui/nixie_on.png');
  static const onairOff = AssetImage('assets/ui/onair_off.png');
  static const onairOn = AssetImage('assets/ui/onair_on.png');
  static const lampOff = AssetImage('assets/ui/lamp_off.png');
  static const lampOn = AssetImage('assets/ui/lamp_on.png');
  static const texAlu = AssetImage('assets/ui/tex_alu.png');
  static const texWalnut = AssetImage('assets/ui/tex_walnut.png');
  static const texRecess = AssetImage('assets/ui/tex_recess.png');
  static const texCrt = AssetImage('assets/ui/tex_crt.png');
}
