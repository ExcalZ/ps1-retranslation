================================================================================

  PHANTASY STAR
  English Retranslation

  Version @VERSION@
  Release Date: @DATE@

  Author: Excalibur_Z
  Platform: Sega Master System

================================================================================


--------------------------------------------------------------------------------
  1. ABOUT THIS PATCH
--------------------------------------------------------------------------------

This patch is a new English translation of Phantasy Star, made from the
Japanese script rather than from the 1987 US localization. It is an
unofficial fan project and is not affiliated with or endorsed by SEGA.

The 1987 release had to fit its English into a font of capital letters,
dialogue lines of 18 characters, item and enemy names of eight letters and
party names of four. Much of the original writing was cut or paraphrased to
fit. This patch rebuilds the text engine so that the game can carry a
translation of the Japanese script in full, in ordinary mixed-case English.

  WHAT IS TRANSLATED

  Dialogue ............ all of it, translated anew from the Japanese
  Story scenes ........ the opening, the story scenes and the ending
  Messages ............ battle, item, shop and system messages
  Menus / windows ..... retranslated, in mixed case
  Names ............... party, items, spells and enemies at their full
                        length

  NAMES

Names follow the Japanese game. Names shared with the later games are
spelled as in the Phantasy Star II and IV retranslations; otherwise the
katakana is transliterated directly. Some of the changes players will
notice first:

  Party:       Alis -> Alisa           Odin -> Tyrone
               Noah -> Lutz            Myau keeps the name.

  World:       Lassic -> LaShiec       Dark Force -> Dark Falz
               Dezoris -> Dezolis      Gothic -> Gashiko
               Baya Malay -> Bayamare  Bortevo -> Bartevo
               Eppi -> Epi             Guaron -> Guaran
               Damor -> Damour

  Spells:      HEAL / CURE -> Heal / Megaheal, BYE -> Whisk,
               FIRE -> Flaeli, THUN -> Tonndre, WIND -> Hyune,
               EXIT -> Evac, RISE -> Rebirth, and so on.

  Items:       COLA -> PelorieMate, BURGER -> Ruoginin,
               LANDROVR / HOVRCRFT / ICE DIGR -> Land Master / Flow
               Mover / Ice Decker, PRISM -> Aeroprism, NUTS -> Laerma
               Berry, and the Japanese equipment names (Silver Tusk,
               Zirconia Mail, Frad Mantle, Perseus Shield ...).

  WHAT CHANGED UNDER THE HOOD

  - Proportional (variable-width) text in the dialogue window, in the
    story scenes and in every menu window.
  - Item and enemy names of up to 14 letters, party names of up to six.
  - The script is stored apart from the original data, so no line had to
    be shortened to fit.
  - Battle commands in the style of Phantasy Star II: each round opens
    with Command, Macro, Talk and Flee. Eight macros (A-H) can be set
    from the field menu's new Macro entry and are saved with the game.
  - The hospital's party menu ends in Everyone: the whole party treated
    at once, for the sum of the separate fees.
  - Faster screen fades, twice the walking speed on the maps, and
    shorter step and turn animations in the dungeons.

  SAVED GAMES

Battery saves from the original game load in this version. The macro
slots start empty.

  HOW IT WAS MADE

This translation was produced by a single author working with the AI
assistant Claude (Anthropic), which was used for script extraction, the
work on the disassembly, the variable-width text engine and the tooling
around them. Every line of the translation was reviewed by the author. The
build was exercised in an emulator through scripted scenarios covering the
field, towns, shops, the hospital, dungeons, battle, the menus and the
story scenes, checked by automated tests that hold every line to its
window's width, and play-tested by the author.


--------------------------------------------------------------------------------
  2. REQUIRED ROM
--------------------------------------------------------------------------------

  Game:          Phantasy Star (USA, Europe), version 3
  Size:          @SRC_SIZE@ bytes  (512 KB / 4 Mbit)
  Header:        none - plain headerless .sms dump

  CRC32:         @SRC_CRC32@
  MD5:           @SRC_MD5@
  SHA-1:         @SRC_SHA1@

The patch applies to this exact ROM only. If your file has a different
size or checksum, the patching tool will refuse it. Earlier US/European
releases and the Japanese release are not supported. A dump with a
512-byte copier header holds the same ROM; Patcher.html removes the
header, other patchers need a headerless file.

No ROM is included with this patch and none will be provided. You must
supply your own copy of the game.


--------------------------------------------------------------------------------
  3. HOW TO PATCH
--------------------------------------------------------------------------------

  EASIEST WAY: Patcher.html

    1. Open Patcher.html from this archive in any web browser.
       It works offline; nothing is uploaded anywhere.
    2. Drop your Phantasy Star ROM onto the page, or click to choose it.
    3. The page checks that your ROM is a supported one, applies the
       patch and offers the result for saving as an .sms file. Never
       overwrite your original ROM.

  WITH A CONVENTIONAL PATCHER

  Patch format:  BPS
  Patch file:    @PATCH@

  Recommended tool: Floating IPS (Flips)
                    https://www.romhacking.net/utilities/1040/

    1. Open Flips and choose "Apply Patch".
    2. Select @PATCH@ from this archive.
    3. Select your unmodified Phantasy Star ROM.
    4. Save the result under a new file name.

  Alternatively, use an online BPS patcher such as the one on
  ROMhacking.net.

  BPS patches store a checksum of the source ROM. If the tool reports a
  mismatch, your ROM is not the expected one - see section 2.


--------------------------------------------------------------------------------
  4. VERIFYING THE RESULT
--------------------------------------------------------------------------------

  After patching, the file should match these values:

  Size:          @OUT_SIZE@ bytes  (1 MB / 8 Mbit)
  CRC32:         @OUT_CRC32@
  MD5:           @OUT_MD5@
  SHA-1:         @OUT_SHA1@

  The patched ROM is 1 MB, twice the original: the new script, font and
  code follow the original data, which stays where SEGA put it. It uses
  the standard Sega mapper, as the original does.

  The header checksum has been recalculated and is valid (@SMSCHK@), so
  the patched ROM passes the console's own integrity check.

  The battery RAM is used as in the original game, so saves work exactly
  as before (section 1, Saved games).


--------------------------------------------------------------------------------
  5. TESTED ON
--------------------------------------------------------------------------------

  Emulator:      Mesen 2.1.1

  This release has not been tested on real hardware. The image is a 1 MB
  ROM on the standard Sega mapper with the game's battery RAM, which flash
  carts that run Phantasy Star should accept, but this is unverified.
  Reports from Master EverDrive / Mega SG owners are welcome.


--------------------------------------------------------------------------------
  6. KNOWN ISSUES
--------------------------------------------------------------------------------

  None known at release.

  Please report text bugs with a savestate or a description of where the
  passage appears, and any other problem with the emulator savestate and a
  note of what was on screen.


--------------------------------------------------------------------------------
  7. CREDITS
--------------------------------------------------------------------------------

  Translation, hacking, testing ......... Excalibur_Z
  Translation and technical support ..... Claude (Anthropic)

  Built on lory90's Phantasy Star disassembly (with Veo's ROM data
  research and Isotarge's labels), without which none of the engine work
  would have been practical.

  Tools ................................. WLA-DX, Mesen,
                                          custom Python tooling

  The original SEGA staff credits are preserved in full. No developer
  has been removed from or replaced in the in-game credit roll.

  Thanks to the ROMhacking.net community and Phantasy Star Cave for the
  documentation and utilities that made this project possible.


--------------------------------------------------------------------------------
  8. LEGAL
--------------------------------------------------------------------------------

  Phantasy Star is copyright SEGA.
  This is an unofficial, non-commercial fan translation distributed as a
  patch file only. It contains no copyrighted game data.

  The patch may be freely redistributed as long as this readme is
  included and no fee is charged. Do not distribute pre-patched ROMs.


--------------------------------------------------------------------------------
  9. CONTACT
--------------------------------------------------------------------------------

  Discord ........... @Excalibur_Z
  Twitter ........... @ExcalZGaming


--------------------------------------------------------------------------------
  10. CHANGELOG
--------------------------------------------------------------------------------

  v@VERSION@  -  @DATE@  -  Initial release


================================================================================
