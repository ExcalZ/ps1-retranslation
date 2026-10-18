# Glossary: naming decisions

The series rule, shared with the PS II, III and IV retranslations: American English, Japanese
names throughout. **PS I names are spelled as the PS IV retranslation ships them** - when a
shared series name comes up, grep `../ps4-translate/work/script_translated.json` and
`dialogue_full.json` (the shipped `en`), not only its glossary table, and
`../ps2-translate/work/glossary.md`, which already follows it. Where modern official material
prints an English form of the katakana, take it; otherwise transliterate, with etymology only
settling ambiguous letters. A katakana word that is an ordinary word (ヤゴ, アリジゴク, ショートケーキ)
is translated, not transliterated.

**Status (2026-10-17): a draft for the owner.** The JP column is now read from the PS I
script (`work/dialogue.json`, `work/script.json`). Rows marked **settled** follow a sibling
translation's shipped text and need no decision; everything else is a proposal, and the
numbered questions at the end are the decisions that block the translation.

PS IV's shipped text (checked 2026-10-17) settles 30 more names; where PS I's own katakana
differs from PS IV's for the same thing, see "PS I and PS IV" below.

Widths: party names 6 letters (`long_names`); items and enemies 12 (`long_item_names`: the
windows show them in capitals, one letter a cell); spells 4 cells (no option widens them yet).

## People

| JP | proposed | US 1987 | note |
|---|---|---|---|
| アリサ | Alisa | Alis | **settled**: PS IV's shipped text ("Alisa's Sword", "Alisa the hero") and the PS II glossary. PS IV's own glossary table still says Alis; its text overrides it |
| ミャウ | Myau | Myau | **settled** (PS IV, PS II). A ジャコウネコ, a musk cat (PS IV ships "musk cat"); the US "some cats" |
| タイロン | Tyron | Odin | **settled** (PS II glossary) |
| ルツ | Lutz | Noah | **settled** (PS IV, PS II). A man: the US made him "her" in one line (`00A8`) |
| ネロ | Nero | Nero | Alisa's brother; she calls him ニイサン |
| ラシーク | LaShiec | Lassic | **settled** (PS IV, PS II) |
| ダークファルス | Dark Falz | Dark Force | **settled** (PS IV, PS II; the US 1987 game already had DARKFALZ in its enemy list) |
| ルベノ (ハカセ) | Dr. Luveno | Dr. Luveno | **settled** (PS IV: Doctor Luveno). His ship ルベノゴウ is "the Luveno" |
| ハプスビー | Hapsby | Hapsby | the robot |
| ソウトク | the Governor | the Governor | as PS II. パセオノソウトク, the Governor of Motavia |
| タジム | Tajim | Tajim | the monk (ドウシ) in the mountains; fought as an enemy (`enemies` 49, US TARZIMAL) |
| ダモア | Damoa | Damor | the soothsayer (ウラナイシ); his item is the Damoa Crystal (the owner, 2026-10-17: the JP reading) |
| ペルセウス | Perseus | Perseus | of the shield |
| エスパー | esper | espar | **settled** (PS IV, PS II) |
| モタビアン / デゾリアン | Motavian / Dezolian | Motavian / Dezorian | **settled** (PS II glossary) |

## Worlds

| JP | proposed | US 1987 | note |
|---|---|---|---|
| アルゴル (タイヨウケイ) | Algol (star system) | Algol | **settled** |
| パルマ / モタビア / デゾリス | Palma / Motavia / Dezolis | Palma / Motavia / Dezoris | **settled** (PS IV, PS II) |
| ラコニア / ラコニアン | Laconia (Laconian Axe alone) | Laconia | **settled** (PS IV, PS III, PS II). The JP has both forms; Laconia for all but the Laconian Axe, which PS IV ships too (the owner, 2026-10-17) |
| メセタ | meseta | meseta | **settled** |

## Places

| JP | proposed | US 1987 | note |
|---|---|---|---|
| カミニート | Camineet | Camineet | the residential area is キョジュウク |
| パロリト | Parolit | Parolit | the JP drops the ッ the US spelling implies; Parolit still reads パロリト |
| シオン | Scion | Scion | a port town. シオン is equally Sion / Zion: question 2 |
| エピ | Epi | Eppi | the forest of lost travellers (マヨイノモリ) and its village (the owner, 2026-10-17: the JP reading) |
| ガシコ | Gashiko | Gothic | the village and the forest (ガシコノモリ) (the owner, 2026-10-17) |
| ロアー | Loar | Loar | |
| アビオン | Abion | Abion | its tower (アビオンノトウ) is the US "tower on a forgotten island" |
| パセオ | Paseo | Paseo | **settled** (PS II). Motavia's capital (シュト) |
| ウーゾ | Uzo | Uzo | **settled** (PS II) |
| カスバ | Casba | Casba | |
| ドラスゴー | Drasgow | Drasgow | |
| ソピア | Sopia | Sopia | the town in the poison gas |
| スクレ | Skure | Skure | **settled** (PS II) |
| バルテボ | Bartevo | Bortevo | the JP vowel is バル (the owner, 2026-10-17) |
| バヤマーレ | Bayamare | Baya Malay | the hill, its tower and the gentle breeze of the ending. PS IV ships Bayamare (its Termi store) (the owner, 2026-10-17) |
| トリアダ | Triada | Triada | the prison south of Camineet |
| グアラン | Guaran | Guaron | the morgue (シタイオキバ) (the owner, 2026-10-17) |
| コロナ (ノトウ) | Corona Tower | Corona Tower | |
| メデューサノトウ | Medusa's Tower | Medusa's Tower | |
| イアラ / ナウラ / マハル | Iala / Naura / Maharu | Iala / Naula / Maharu | caves. Naura **settled** (PS IV ships its cake shop as Naura). マハル could be Mahal; Maharu kept |
| デゾリスノドウクツ | the Dezolis Cave | the Dezoris Cave | |
| アルチプラノ | Altiplano | Altiplano | the plateau of the Laerma trees |
| スペースポート | spaceport | spaceport | |
| キョウカイ | church | church | |
| エアロキャッスル | the Air Castle | a celestial castle | LaShiec's castle: as PS IV ships it (エアキャッスル there), though PS I spells it エアロ (the owner, 2026-10-17) |
| アクマノシロ | the Devil's Castle | the Dark Castle | what the King calls it in the ending (`0278`) |

## Items (12 letters, `long_item_names`)

The JP names are long katakana compounds; translated or transliterated whole, 20 of the 64
run past 12 letters (and 8 of the 74 enemies). **Question 4** is how to fit them; the third column is the full form, the
fourth a 12-letter form under one convention (a space dropped, then Swd / Shld, the series'
own menu abbreviations), only where the full form does not fit.

| # | JP | full form | 12-letter form | US 1987 | note |
|---|---|---|---|---|---|
| 1 | ウッドケイン | Wood Cane |  | WOODCANE | **settled** (PS IV ships it) |
| 2 | ショートソード | Short Sword | | SHT. SWD | |
| 3 | アイアンソード | Iron Sword | | IRN. SWD | |
| 4 | サイコウオンド | Psycho Wand | | WAND | **settled** (PS IV) |
| 5 | シルバータスク | Silver Tusk |  | IRN.FANG | **settled** (PS IV ships it). Myau's |
| 6 | アイアンアクス | Iron Axe | | IRN. AXE | |
| 7 | チタニウムソード | Titanium Sword | Titanium Swd | TIT. SWD | **settled** (PS IV ships it) |
| 8 | セラミックソード | Ceramic Sword | Ceramic Swd | CRC. SWD | **settled** (PS IV ships it) |
| 9 | ニードルガン | Needle Gun | | NEEDLGUN | |
| 10 | サーベルクロー | Saber Claw | | SIL.FANG | |
| 11 | ヒートガン | Heat Gun | | HEAT.GUN | |
| 12 | ライトセイバー | Light Saber | | LGT.SABR | two words, not the trademark |
| 13 | レーザーガン | Laser Gun | | LASR.GUN | |
| 14 | ラコニアンソード | Laconia Sword | | LAC. SWD | Laconia for all but the axe (the owner, 2026-10-17; PS IV ships Laconia Sword) |
| 15 | ラコニアンアクス | Laconian Axe | | LAC. AXE | as PS IV ships it (the owner, 2026-10-17) |
| 16 | レザークロス | Leather Cloth | LeatherCloth | LTH.ARMR | **settled** (PS IV ships it) |
| 17 | ホワイトマント | White Cape |  | WHT.MANT | **settled** (PS IV ships it) (not Mantle, though マント) |
| 18 | ライトスーツ | Light Suit | | LGT.SUIT | |
| 19 | アイアンアーマー | Iron Armor | | IRN.ARMR | |
| 20 | トゲリスノケガワ | Spiny Squirrel Pelt | Spiny Pelt | THCK.FUR | トゲリス, a thorn squirrel: a made-up beast |
| 21 | ジルコニアメイル | Zirconia Mail | ZirconiaMail | ZIR.ARMR | |
| 22 | ダイヤノヨロイ | Diamond Armor | Diamond Mail | DMD.ARMR | ヨロイ is armor; Mail as #21 |
| 23 | ラコニアアーマー | Laconia Armor | Laconia Mail | LAC.ARMR | **settled** (PS IV ships it) |
| 24 | フラードマント | Frad Mantle |  | FRD.MANT | **settled** (PS IV ships it) |
| 25 | レザーシールド | Leather Shield | Leather Shld | LTH. SLD | **settled** (PS IV ships it) |
| 26 | アイアンシールド | Iron Shield | | BRNZ.SLD | the US swapped 26 and 27's materials |
| 27 | ボロンシールド | Boron Shield | | IRN. SLD | |
| 28 | セラミックノタテ | Ceramic Shield | Ceramic Shld | CRC. SLD | |
| 29 | アニマルグラブ | Animal Glove | | GLOVE | Myau's |
| 30 | レーザーバリア | Laser Barrier | LaserBarrier | LASR.SLD | **settled** (PS IV ships it) |
| 31 | ペルセウスノタテ | Perseus Shield | Perseus Shld | MIRR.SLD | the shield of Perseus |
| 32 | ラコニアシールド | Laconia Shield | Laconia Shld | LAC. SLD | **settled** (PS IV ships it) |
| 33 | ランドマスター | Land Master | | LANDROVR | **settled** (PS IV) |
| 34 | フロームーバー | Flow Mover |  | HOVRCRFT | **settled** (PS IV ships it) |
| 35 | アイスデッカー | Ice Decker |  | ICE DIGR | **settled** (PS IV ships it) |
| 36 | ペロリーメイト | PelorieMate | | COLA | **settled** (PS IV) |
| 37 | ルオギニン | Ruoginin | | BURGER | |
| 38 | スーズフルート | Soothe Flute | | FLUTE | スーズ, soothe |
| 39 | サーチライト | Searchlight | | FLASH | |
| 40 | エスケープクロス | Escape Cloth | | ESCAPER | |
| 41 | トランカーペット | Tran Carpet | | TRANSER | トラン(ス), trans-; or Trans Carpet |
| 42 | マジックハット | Magic Hat | | MAGC HAT | |
| 43 | アルシュリン | Alshlin | | ALSULIN | **settled** (PS IV chose Alshlin over Alsulin) |
| 44 | ポリメテラール | Polymeteral | | POLYMTRL | |
| 45 | ダンジョンキー | Dungeon Key | | DUGN KEY | |
| 46 | テレパシーボール | Telepathy Ball | TelepathBall | SPHERE | **settled** (PS IV ships it) (in its dialogue) |
| 47 | イクリプストーチ | Eclipse Torch | EclipseTorch | TORCH | the name **settled** (PS IV), the width not |
| 48 | エアロプリズム | Aeroprism |  | PRISM | as PS IV's shipped text (the owner, 2026-10-17) |
| 49 | ラエルマベリー | Laerma Berry | | NUTS | from the ラエルマツリー |
| 50 | ハプスビー | Hapsby | | HAPSBY | |
| 51 | ロードパス | Road Pass | | ROADPASS | |
| 52 | パスポート | Passport | | PASSPORT | |
| 53 | コンパス | Compass | | COMPASS | |
| 54 | ショートケーキ | Shortcake |  | CAKE | **settled** (PS IV ships it) |
| 55 | ソウトクノテガミ | Governor's Letter | Gov's Letter | LETTER | or plain Letter |
| 56 | ラコニアンポット | Laconia Pot | | LAC. POT | Laconia for all but the axe (the owner, 2026-10-17) |
| 57 | ライトペンダント | Light Pendant | LightPendant | MAG.LAMP | |
| 58 | カーバンクルアイ | Carbuncle Eye | CarbuncleEye | AMBR EYE | |
| 59 | ガスクリア | Gas Clear | | GAS. SLD | the dialogue spells it ガスクリアー |
| 60 | ダモアクリスタル | Damoa Crystal | DamoaCrystal | CRYSTAL | |
| 61 | マスターシステム | Master System | MasterSystem | M SYSTEM | the console, an in-joke item |
| 62 | ミラクルキー | Miracle Key | | MRCL KEY | |
| 63 | ジリオン | Zillion | | ZILLION | the Sega game |
| 64 | ヒミツノモノ | Secret Thing | | SECRETS | |

## Enemies (12 letters, `long_item_names`)

| # | JP | full form | 12-letter form | US 1987 | note |
|---|---|---|---|---|---|
| 1 | モンスターフライ | Monster Fly |  | SWORM | **settled** (PS IV ships it) |
| 2 | グリーンスライム | Green Slime | | GR.SLIME | |
| 3 | ウイングアイ | Wing Eye | | WING EYE | |
| 4 | マンイーター | Man-Eater | | MANEATER | |
| 5 | スコーピラス | Scorpirus |  | SCORPION | **settled** (PS IV ships it) |
| 6 | ラージヤーゴ | Large Nymph | | G.SCORPI | ヤゴ, a dragonfly nymph |
| 7 | ブルースライム | Blue Slime | | BL.SLIME | |
| 8 | モタビアンノーフ | Motavian Nof | | N.FARMER | ノーフ unexplained; provisional |
| 9 | デビルバット | Devil Bat | | OWL BEAR | |
| 10 | キラープラント | Killer Plant | | DEADTREE | |
| 11 | バイターフライ | Biter Fly |  | SCORPIUS | **settled** (PS IV ships it) |
| 12 | モタビアンイビル | Motavian Evil | MotavianEvil | E.FARMER | |
| 13 | ヘレックス | Herex | | GIANTFLY | |
| 14 | サンドワーム | Sand Worm |  | CRAWLER | **settled** (PS IV ships it), two words |
| 15 | モタビアンマニア | Berserker |  | BARBRIAN | as PS IV ships it (the owner, 2026-10-17) |
| 16 | ゴールドレンズ | Gold Lens | | GOLDLENS | |
| 17 | レッドスライム | Red Slime | | RD.SLIME | |
| 18 | バットマン | Bat Man | | WERE BAT | two words, not the trademark |
| 19 | カブトガニ | Horseshoe Crab | HorseshoeCrb | BIG CLUB | カブトガニ is the horseshoe crab: question 4 |
| 20 | シャーキン | Sharkin | | FISHMAN | |
| 21 | リッチ | Lich | | EVILDEAD | |
| 22 | タランチュラ | Tarantula | | TARANTUL | |
| 23 | マンチコア | Manticore | | MANTICOR | |
| 24 | スケルトン | Skeleton | | SKELETON | |
| 25 | アリジゴク | Antlion | | ANT LION | |
| 26 | マーシーズ | Marshes | | MARMAN | provisional |
| 27 | デゾリアン | Dezolian | | DEZORIAN | **settled** (PS II) |
| 28 | デザートリーチ | Desert Leech |  | LEECH | **settled** (PS IV ships it) |
| 29 | クライオン | Crion | | VAMPIRE | provisional |
| 30 | ビッグノーズ | Big Nose | | ELEPHANT | |
| 31 | グール | Ghoul |  | GHOUL | **settled** (PS IV ships it) |
| 32 | アンモナイト | Ammonite | | SHELFISH | |
| 33 | エグゼキュート | Execute | | EXECUTER | |
| 34 | ワイト | Wight | | WIGHT | |
| 35 | スカルソルジャー | Skull Soldier | SkullSoldier | SKULL-EN | |
| 36 | マイマイ | Snail | | AMMONITE | マイマイ is a snail |
| 37 | マンチコート | Manticort | | SPHINX | provisional (a play on マンチコア) |
| 38 | サーペント | Serpent | | SERPENT | |
| 39 | リバイアサン | Leviathan |  | SANDWORM | **settled** (PS IV ships it) (its JP リヴァイアサン; PS I has no ヴ) |
| 40 | ドルージュ | Druj | | LICH | the Zoroastrian demon of the lie; provisional |
| 41 | オクトパス | Octopus | | OCTOPUS | |
| 42 | マッドストーカー | Mad Stalker | | STALKER | |
| 43 | デゾリアンヘッド | Dezolian Head | DezolianHead | EVILHEAD | |
| 44 | ゾンビ | Zombie |  | ZOMBIE | **settled** (PS IV ships it) |
| 45 | ビュート | Butte | | BATALION | provisional |
| 46 | ロボットポリス | Robot Police | | ROBOTCOP | |
| 47 | サイボーグメイジ | Cyborg Mage | | SORCERER | |
| 48 | フレームリザード | Flame Lizard | | NESSIE | |
| 49 | タジム | Tajim | | TARZIMAL | the monk |
| 50 | ガイア | Gaia | | GOLEM | |
| 51 | マシーンガーダー | Machine Guarder | MachineGuard | ANDROCOP | |
| 52 | ビッグイーター | Big Eater | | TENTACLE | |
| 53 | タロス | Talos | | GIANT | |
| 54 | スネークロード | Snake Lord | | WYVERN | |
| 55 | デスベアラー | Death Bearer | | REAPER | |
| 56 | カオスソーサラー | Chaos Sorcerer | ChaosSorcer. | MAGICIAN | **settled** (PS IV ships it) and PS II |
| 57 | セントール | Centaur |  | HORSEMAN | **settled** (PS IV ships it) |
| 58 | アイスマン | Ice Man | | FROSTMAN | |
| 59 | バルカン | Vulcan | | AMUNDSEN | |
| 60 | レッドドラゴン | Red Dragon | | RD.DRAGN | |
| 61 | グリーンドラゴン | Green Dragon | | GR.DRAGN | |
| 62 | ラシーク | LaShiec | | SHADOW | his double (カゲムシャ, `0266`) |
| 63 | マンモス | Mammoth | | MAMMOTH | |
| 64 | キングセイバー | King Saber |  | CENTAUR | **settled** (PS IV ships it) |
| 65 | ダークマローダー | Dark Marauder | DarkMarauder | MARAUDER | **settled** (PS IV ships it) |
| 66 | ゴーレム | Golem | | TITAN | |
| 67 | メデューサ | Medusa | | MEDUSA | |
| 68 | フロストドラゴン | Frost Dragon | | WT.DRAGN | |
| 69 | ドラゴンワイズ | Dragon Wise | | BL.DRAGN | |
| 70 | ゴールドドレイク | Gold Drake | | GD.DRAGN | |
| 71 | マッドドクター | Mad Doctor | | DR.MAD | |
| 72 | ラシーク | LaShiec | | LASSIC | |
| 73 | ダークファルス | Dark Falz | | DARKFALZ | **settled** |
| 74 | ナイトメア | Nightmare |  | SACCUBUS | **settled** (PS IV ships it) |

## Spells (4 cells today)

Five of PS I's spells are PS IV techniques, and PS IV's shipped text settles them. The rest are
transliterations. Only Heal fits the 4-cell lists: **question 5**.

| JP | proposed | US 1987 | note |
|---|---|---|---|
| ヒール | Heal | HEAL | |
| ドヒール | Doheal | CURE | the ド- prefix |
| ラクスタ | Rakusta | BYE | escape from battle |
| ペヤラク | Peyarak | CHAT | talk to enemies |
| フレエリ | Flaeli | FIRE | **settled** (PS IV ships Flaeli) |
| ビンドワ | Bindwa | ROPE | **settled** (PS IV) |
| テルル | Terror | TERR | **settled** (PS IV: Terror, after PS I's TERR) |
| ワーラ | Waller | WALL | **settled** (PS IV ships Waller) |
| ムワーラ | Muwaller | PROT | the ム- form of Waller |
| タンドレ | Tonndre | THUN | **settled** (PS IV ships Tonndre) |
| パウマ | Pauma | HELP | |
| テレパス | Telepath | TELE | |
| ヒューン | Hyune | WIND | **settled** (PS IV ships Hyune) |
| トルーパ | Trupa | FLY | provisional |
| ラプット | Raputt | TRAP | provisional |
| スルト | Surt | EXIT | |
| ムオーデ | Muode | OPEN | |
| リーバス | Reebus | RISE | provisional |

## Menus (in the face, `vwf_windows`; in script.json since 2026-10-17)

The JP menu words, translated; each fits its stock cells in the face.

| JP | this translation | US 1987 |
|---|---|---|
| タタカウ / マジック / アイテム / ハナス / ニゲル | Fight / Magic / Item / Talk / Flee (the battle menu) | ATTK MAGC ITEM TALK RUN |
| ツヨサ / シラベル / セーブ | Stats / Search / Save (the command menu, with Magic and Item) | STAS SRCH SAVE |
| ツカウ / ソウビ / ステル | Use / Equip / Drop | USE EQP DRP |
| カイタイ / ウリタイ | Buy / Sell | BUY SELL |
| ハイ / イイエ | Yes / No | YES NO |
| コウゲキリョク / シュビリョク / サイダイHP / サイダイMP | Attack / Defense / Max HP / Max MP | ATTACK DEFENSE MAX HP MAX MP |
| ホカノ モチモノ | More (the inventory's next page) | NEXT |
| メセタ | Meseta (the money line, the owner) | MST |

## In script.json (2026-10-17)

Every name field holds the forms above: the party (Alisa, Myau, Tyron, Lutz), the 64 items, the
74 enemies and the spells, each at most 14 letters and 80 px in the face (`vwf_windows` lists
them 10 cells wide). The full form where it fits, otherwise: Spiny Pelt (トゲリスノケガワ),
Gov's Letter (ソウトクノテガミ), Machine Guard (マシーンガーダー, 15 letters as Guarder). The owner
answered questions 1-3 and 6-8 the same day (Gashiko, the JP readings, Air Castle, Laconia but
for the Laconian Axe, Aeroprism, Berserker).

## Other words

| JP | proposed | US 1987 |
|---|---|---|
| ダンジョン | dungeon | dungeon |
| マジック / マホウ | magic | magic |
| マッドドクター | the Mad Doctor | the mad doctor |
| アルテムハムラム アルテムハムハムストラトポン | the church's spell, kept as the JP's sounds | SABRUS CABRUS SEBRUS BASS |
| カイゲンレイ | martial law | martial law |
| メセタ (the money line) | Meseta (the owner, 2026-10-17: the label in the face, "Meseta 2000") | MST |

## Voices

* **Dezolians speak with an American Southern accent** (the owner, 2026-10-17), as PS II and
  PS IV render their ズラ: "us folks", "ain't", "I reckon", "y'know", dropped g's, "'em".
  Audible but readable, not the US 1987 "ze/zis". PS I has two Dezolian villages:
  * ズラ (`01C8`-`01DC`, the village that hates Palmans): the broader, gruffer form ("Folks
    next door ain't nothin' but liars", "Us folks here can't stand Palma people, no sir").
  * ンダス (`01DE`-`01E6`, the village that welcomes them): a gentler, courteous Southern
    ("Why, there's...", "sure enough", "don't ya know", "Y'all from Palma are mighty
    welcome").
* **In-jokes the US replaced are kept** from the JP: "big sister Choko" (`0188`), Chie of
  the letters page (`027A`, where the US put an Aeroprism hint).

## PS I and PS IV: the same things, different katakana

* **エアロキャッスル (PS I) / エアキャッスル (PS IV)**: LaShiec's castle (question 3).
* **ラコニアンソード (PS I) / ラコニアソード (PS IV)**: PS IV drops the ン for the sword only.
* **ラコニアンアクス (PS I) / ラコニアンアックス (PS IV)**: the same word, PS I without the ッ.
* Font limits, not differences: PS I's kana have no ォ ィ ェ ヴ ・ (its only small vowel is ァ), so
  サイコウオンド is PS IV's サイコウォンド (Psycho Wand), リバイアサン its リヴァイアサン (Leviathan) and
  ダークファルス its ダーク・ファルス.
* Within PS I: the item ガスクリア is ガスクリアー in the dialogue; ラエルマベリー grows on the
  ラエルマツリー (PS IV's Laerma tree).

## Questions for the owner (all answered 2026-10-17)

1. **Answered (the owner, 2026-10-17): Gashiko.**
2. **Answered (the owner, 2026-10-17): the JP readings** - Bartevo, Bayamare, Guaran, Epi, Damoa.
3. **Answered (the owner, 2026-10-17): Air Castle**, as PS IV ships it.
4. **Answered (the owner, 2026-10-17): "Expand windows as necessary, but accommodate mixed-case"** - the
   windows widen as the names need, and show them in mixed case. Built the same day:
   `vwf_windows` draws every window's text in the face; names up to 14 letters and 80 px, in
   windows 10 cells wide (`docs/pipeline.md` 6). The question was: **Item and enemy names over 12 letters (20 items, 8 enemies).** Either (a) the 12-letter forms
   above (a space dropped, Swd / Shld), or (b) widen `long_item_names` to 14 letters. By the
   window map (`docs/pipeline.md` 3.7) every window that lists them has 2 more free cells to its
   left (the inventory to c16, the shop list and the equipment box to c0, the enemy name box to
   c8); not built or tried yet. Then only three need a short form: Spiny Squirrel Pelt (Spiny
   Pelt), Governor's Letter (Gov's Letter) and Machine Guarder (MachineGuarder, 14). Proposed:
   (b), the 14-letter windows.
5. **Answered with 4** (windows widen as necessary: the spell lists too). The question was: **Spells:** the transliterations need 5-8 cells and the spell lists are 4 wide. Either (a) an
   engine option for 8-cell spell lists (as PS II's `wide_techs`), or (b) keep 4-letter
   English spell words. Proposed: (a).
6. **Answered (the owner, 2026-10-17): Laconia for all, except the Laconian Axe**, which PS IV ships too:
   Laconia Sword, Laconia Pot, Laconia Armor, Laconia Shield; Laconian Axe.
7. **Answered (the owner, 2026-10-17): Aeroprism.**
8. **Answered (the owner, 2026-10-17): Berserker.**
